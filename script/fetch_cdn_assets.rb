#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "pathname"
require "bundler/setup"
require "faraday"

CDN_PATTERN = %r{https://hc-cdn\.hel1\.your-objectstorage\.com/s/v3/([A-Za-z0-9._-]+)}
ARCHIVE_PREFIX = "https://web.archive.org/web/20270123013947im_/"
RATE_LIMIT_SECONDS = 0.1
MAX_RETRIES = 5
BASE_BACKOFF = 2.0
MAX_BACKOFF = 60.0
JITTER = 0.5
HTTP_TIMEOUT = 30
THREAD_COUNT = 25

OUTPUT_DIR = Pathname.new(File.expand_path("../../public/old-cdn", __FILE__))
MAPPING_FILE = Pathname.new(File.expand_path("../../tmp/old_cdn_mapping.json", __FILE__))
FAILURES_FILE = Pathname.new(File.expand_path("../../tmp/old_cdn_failures.json", __FILE__))

class InternetArchiveFetcher
  RETRYABLE_CODES = %w[429 500 502 503 504].freeze

  def initialize
    @mapping = load_existing_mapping
    @failures = []
    @mutex = Mutex.new
    @counter = 0
  end

  def run
    urls = scan_codebase
    puts "Found #{urls.size} unique URLs in codebase"

    urls_to_fetch = urls.reject do |url|
      rel_path = url.match(CDN_PATTERN)[1]
      local_path = OUTPUT_DIR.join(rel_path)

      if local_path.exist? && local_path.size.positive?
        @mapping[url] = "/old-cdn/#{rel_path}"
        true
      elsif @mapping.key?(url)
        true
      else
        false
      end
    end

    puts "Skipping #{urls.size - urls_to_fetch.size} already fetched"
    puts "Fetching #{urls_to_fetch.size} URLs with #{THREAD_COUNT} threads"
    @total = urls_to_fetch.size

    return save_results if urls_to_fetch.empty?

    queue = Queue.new
    urls_to_fetch.each { |url| queue << url }

    threads = THREAD_COUNT.times.map do
      Thread.new do
        while (url = queue.pop(true) rescue nil)
          process_url(url)
          sleep(RATE_LIMIT_SECONDS)
        end
      end
    end

    threads.each(&:join)

    save_results
    print_summary
  end

  private

  def load_existing_mapping
    return {} unless MAPPING_FILE.exist?

    JSON.parse(MAPPING_FILE.read)
  rescue JSON::ParserError
    {}
  end

  def scan_codebase
    files = `git ls-files -z`.split("\0")
    urls = Set.new

    files.each do |file|
      next unless File.file?(file)
      next if binary_file?(file)

      content = File.read(file, mode: "rb")
      content.scan(CDN_PATTERN) do
        urls << Regexp.last_match(0)
      end
    rescue StandardError => e
      warn "Error reading #{file}: #{e.message}"
    end

    urls.to_a.sort
  end

  def binary_file?(path)
    ext = File.extname(path).downcase
    %w[.png .jpg .jpeg .gif .ico .woff .woff2 .ttf .eot .pdf .zip .tar .gz .mp4 .mp3 .webp .svg].include?(ext)
  end

  def process_url(url)
    current = @mutex.synchronize { @counter += 1 }
    rel_path = url.match(CDN_PATTERN)[1]
    local_path = OUTPUT_DIR.join(rel_path)

    archive_url = "#{ARCHIVE_PREFIX}#{url}"
    body = download_with_retry(archive_url)

    unless body
      puts "[#{current}/#{@total}] FAIL: #{rel_path}"
      @mutex.synchronize { @failures << { url: url, reason: "download_failed", archive_url: archive_url } }
      return
    end

    FileUtils.mkdir_p(local_path.dirname)
    File.binwrite(local_path, body)
    @mutex.synchronize { @mapping[url] = "/old-cdn/#{rel_path}" }
    puts "[#{current}/#{@total}] OK: #{rel_path} (#{body.bytesize} bytes)"
  end

  def download_with_retry(url)
    result = http_get_with_retry(url)
    return result[:body] if result[:success]

    warn "  Error: #{result[:error]}"
    nil
  end

  def http_get_with_retry(url)
    attempt = 0
    last_error = nil

    loop do
      attempt += 1

      response = follow_redirects(url)

      case response.status
      when 200..299
        return { success: true, body: response.body }
      when 404
        if attempt < MAX_RETRIES
          backoff = calculate_backoff(attempt)
          warn "  Retry #{attempt}/#{MAX_RETRIES} after #{backoff.round(1)}s (HTTP 404 - may be transient)"
          sleep(backoff)
          next
        end
        last_error = "HTTP 404 - Not found in Internet Archive"
      when 429, 500..599
        if attempt < MAX_RETRIES
          backoff = calculate_backoff(attempt)
          warn "  Retry #{attempt}/#{MAX_RETRIES} after #{backoff.round(1)}s (HTTP #{response.status})"
          sleep(backoff)
          next
        end
        last_error = "HTTP #{response.status} after #{MAX_RETRIES} retries"
      else
        last_error = "HTTP #{response.status}"
      end

      return { success: false, error: last_error } if attempt >= MAX_RETRIES

      break
    end

    { success: false, error: last_error || "Unknown error" }
  rescue StandardError => e
    if attempt < MAX_RETRIES
      backoff = calculate_backoff(attempt)
      warn "  Retry #{attempt}/#{MAX_RETRIES} after #{backoff.round(1)}s (#{e.class}: #{e.message})"
      sleep(backoff)
      retry
    end
    { success: false, error: "#{e.class}: #{e.message}" }
  end

  def faraday_client
    @faraday_client ||= Faraday.new do |f|
      f.options.timeout = HTTP_TIMEOUT
      f.options.open_timeout = HTTP_TIMEOUT
      f.headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
      f.headers["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8"
      f.headers["Accept-Language"] = "en-US,en;q=0.9"
      f.headers["Referer"] = "https://web.archive.org/"
      f.adapter Faraday.default_adapter
    end
  end

  def follow_redirects(url, limit = 5)
    limit.times do
      response = faraday_client.get(url)
      return response unless [ 301, 302, 303, 307, 308 ].include?(response.status)

      url = response.headers["location"]
      return response if url.nil?
    end
    faraday_client.get(url)
  end

  def calculate_backoff(attempt, response = nil)
    if response&.key?("Retry-After")
      return response["Retry-After"].to_i
    end

    base = [ BASE_BACKOFF * (2**(attempt - 1)), MAX_BACKOFF ].min
    base + rand * JITTER
  end

  def save_results
    FileUtils.mkdir_p(MAPPING_FILE.dirname)
    File.write(MAPPING_FILE, JSON.pretty_generate(@mapping))
    File.write(FAILURES_FILE, JSON.pretty_generate(@failures)) if @failures.any?
  end

  def print_summary
    puts "\n" + "=" * 60
    puts "SUMMARY"
    puts "=" * 60
    puts "Successfully mapped: #{@mapping.size}"
    puts "Failed: #{@failures.size}"
    puts "Mapping saved to: #{MAPPING_FILE}"
    puts "Failures saved to: #{FAILURES_FILE}" if @failures.any?
  end
end

InternetArchiveFetcher.new.run
