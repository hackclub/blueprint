#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"
require "fileutils"

OLD_CDN_DIR = Pathname.new(File.expand_path("../../public/old-cdn", __FILE__))
IMAGE_EXTENSIONS = %w[.png .jpg .jpeg .gif].freeze
TEXT_EXTENSIONS = %w[.rb .erb .haml .slim .js .ts .jsx .tsx .css .scss .sass .html .yml .yaml .json .md .txt].freeze
MAX_SIZE = 1000
QUALITY = 80
THREAD_COUNT = 8

class ImageOptimizer
  def initialize
    @conversions = {}
    @mutex = Mutex.new
    @counter = 0
  end

  def run
    images = find_images
    puts "Found #{images.size} images to optimize"

    return if images.empty?

    @total = images.size
    queue = Queue.new
    images.each { |img| queue << img }

    threads = THREAD_COUNT.times.map do
      Thread.new do
        while (image = queue.pop(true) rescue nil)
          process_image(image)
        end
      end
    end

    threads.each(&:join)

    puts "\nConverted #{@conversions.size} images"
    puts "\nUpdating references in codebase..."
    update_references
    puts "Done."
  end

  private

  def find_images
    Dir.glob(OLD_CDN_DIR.join("*")).select do |f|
      IMAGE_EXTENSIONS.include?(File.extname(f).downcase)
    end
  end

  def process_image(image_path)
    current = @mutex.synchronize { @counter += 1 }
    basename = File.basename(image_path)
    name_without_ext = File.basename(image_path, ".*")
    webp_name = "#{name_without_ext}.webp"
    webp_path = OLD_CDN_DIR.join(webp_name)

    if webp_path.exist?
      puts "[#{current}/#{@total}] SKIP (exists): #{webp_name}"
      @mutex.synchronize { @conversions[basename] = webp_name }
      return
    end

    # cwebp command: resize to max 1000px, convert to webp at 80% quality
    cmd = [
      "cwebp",
      "-q", QUALITY.to_s,
      "-resize", MAX_SIZE.to_s, "0",  # 0 means auto-calculate to keep aspect ratio
      image_path,
      "-o", webp_path.to_s
    ]

    result = system(*cmd, out: File::NULL, err: File::NULL)

    if result && webp_path.exist?
      old_size = File.size(image_path)
      new_size = File.size(webp_path)
      savings = ((1 - new_size.to_f / old_size) * 100).round(1)
      puts "[#{current}/#{@total}] OK: #{basename} -> #{webp_name} (#{savings}% smaller)"
      @mutex.synchronize { @conversions[basename] = webp_name }
    else
      puts "[#{current}/#{@total}] FAIL: #{basename}"
    end
  end

  def update_references
    return if @conversions.empty?

    files_changed = 0
    total_replacements = 0

    `git ls-files -z`.split("\0").each do |path|
      next unless File.file?(path)
      next unless TEXT_EXTENSIONS.include?(File.extname(path).downcase)

      content = File.read(path, mode: "rb") rescue next
      next unless content.valid_encoding?

      replacements = 0
      @conversions.each do |old_name, new_name|
        old_link = "/old-cdn/#{old_name}"
        new_link = "/old-cdn/#{new_name}"

        count = content.scan(old_link).size
        if count.positive?
          content.gsub!(old_link, new_link)
          replacements += count
        end
      end

      next if replacements.zero?

      files_changed += 1
      total_replacements += replacements
      puts "  #{path}: #{replacements} replacement(s)"
      File.write(path, content)
    end

    puts "Files changed: #{files_changed}, Total replacements: #{total_replacements}"
  end
end

ImageOptimizer.new.run
