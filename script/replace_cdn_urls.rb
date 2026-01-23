#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "pathname"

MAPPING_FILE = Pathname.new(File.expand_path("../../tmp/old_cdn_mapping.json", __FILE__))

TEXT_EXTENSIONS = %w[
  .rb .erb .haml .slim .js .ts .jsx .tsx .css .scss .sass
  .html .yml .yaml .json .md .txt .rake .gemspec .lock
].freeze

class CdnUrlReplacer
  def initialize(dry_run: false)
    @dry_run = dry_run
    @files_changed = 0
    @total_replacements = 0
  end

  def run
    unless MAPPING_FILE.exist?
      abort "Error: Mapping file not found at #{MAPPING_FILE}\nRun fetch_cdn_assets.rb first."
    end

    @mapping = JSON.parse(MAPPING_FILE.read)
    puts "Loaded #{@mapping.size} URL mappings"
    puts "DRY RUN MODE - no files will be modified" if @dry_run

    files = `git ls-files -z`.split("\0")
    files.each { |file| process_file(file) }

    print_summary
  end

  private

  def process_file(path)
    return unless File.file?(path)
    return unless text_file?(path)

    content = File.read(path, mode: "rb")
    return unless content.valid_encoding? || content.force_encoding("UTF-8").valid_encoding?

    original = content.dup
    replacements = 0

    @mapping.each do |old_url, new_path|
      count = content.scan(old_url).size
      if count.positive?
        content.gsub!(old_url, new_path)
        replacements += count
      end
    end

    return if replacements.zero?

    @files_changed += 1
    @total_replacements += replacements

    puts "#{path}: #{replacements} replacement(s)"

    return if @dry_run

    File.write(path, content)
  end

  def text_file?(path)
    ext = File.extname(path).downcase
    TEXT_EXTENSIONS.include?(ext)
  end

  def print_summary
    puts "\n" + "=" * 60
    puts "SUMMARY"
    puts "=" * 60
    puts "Files changed: #{@files_changed}"
    puts "Total replacements: #{@total_replacements}"
    puts "(DRY RUN - no changes written)" if @dry_run
  end
end

dry_run = ARGV.include?("--dry-run")
CdnUrlReplacer.new(dry_run: dry_run).run
