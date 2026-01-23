#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

OLD_CDN_DIR = Pathname.new(File.expand_path("../../public/old-cdn", __FILE__))
OLD_CDN_PATTERN = %r{https://hc-cdn\.hel1\.your-objectstorage\.com/s/v3/[A-Za-z0-9._-]+}
NEW_CDN_PATTERN = %r{/old-cdn/([A-Za-z0-9._-]+)}
TEXT_EXTENSIONS = %w[.rb .erb .haml .slim .js .ts .jsx .tsx .css .scss .sass .html .yml .yaml .json .md .txt].freeze

old_cdn_links = []
missing_files = []
valid_links = 0

files = `git ls-files -z`.split("\0")

files.each do |path|
  next unless File.file?(path)
  next unless TEXT_EXTENSIONS.include?(File.extname(path).downcase)

  content = File.read(path, mode: "rb") rescue next
  next unless content.valid_encoding?

  # Check for old CDN links
  content.scan(OLD_CDN_PATTERN) do |match|
    old_cdn_links << { file: path, url: match }
  end

  # Check for new CDN links with missing files
  content.scan(NEW_CDN_PATTERN) do |match|
    filename = match[0]
    file_path = OLD_CDN_DIR.join(filename)

    if file_path.exist?
      valid_links += 1
    else
      missing_files << { file: path, link: "/old-cdn/#{filename}" }
    end
  end
end

puts "=" * 60
puts "CDN MIGRATION VERIFICATION"
puts "=" * 60

puts "\n1. OLD CDN LINKS (should be 0)"
puts "-" * 40
if old_cdn_links.empty?
  puts "✓ No old CDN links found"
else
  puts "✗ Found #{old_cdn_links.size} old CDN links:"
  old_cdn_links.each do |link|
    puts "  #{link[:file]}: #{link[:url]}"
  end
end

puts "\n2. MISSING FILES (should be 0)"
puts "-" * 40
if missing_files.empty?
  puts "✓ All /old-cdn/ links have corresponding files"
else
  puts "✗ Found #{missing_files.size} links with missing files:"
  missing_files.each do |link|
    puts "  #{link[:file]}: #{link[:link]}"
  end
end

puts "\n3. SUMMARY"
puts "-" * 40
puts "Valid /old-cdn/ links: #{valid_links}"
puts "Old CDN links remaining: #{old_cdn_links.size}"
puts "Missing files: #{missing_files.size}"

exit_code = (old_cdn_links.empty? && missing_files.empty?) ? 0 : 1
exit exit_code
