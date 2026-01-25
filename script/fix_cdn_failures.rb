#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "fileutils"
require "pathname"

OLD_CDN_DIR = Pathname.new(File.expand_path("../../public/old-cdn", __FILE__))
MAPPING_FILE = Pathname.new(File.expand_path("../../tmp/old_cdn_mapping.json", __FILE__))
FAILURES_FILE = Pathname.new(File.expand_path("../../tmp/old_cdn_failures.json", __FILE__))

unless FAILURES_FILE.exist?
  puts "No failures file found"
  exit 0
end

failures = JSON.parse(FAILURES_FILE.read)
mapping = MAPPING_FILE.exist? ? JSON.parse(MAPPING_FILE.read) : {}
existing_files = Dir.entries(OLD_CDN_DIR).reject { |f| f.start_with?(".") }

fixed = []
remaining = []

failures.each do |failure|
  url = failure["url"]
  full_name = url.split("/").last
  short_name = full_name.split("_", 2).last

  if existing_files.include?(full_name)
    mapping[url] = "/old-cdn/#{full_name}"
    fixed << { url: url, file: full_name, action: "already exists" }
  elsif existing_files.include?(short_name)
    old_path = OLD_CDN_DIR.join(short_name)
    new_path = OLD_CDN_DIR.join(full_name)

    FileUtils.mv(old_path, new_path)
    mapping[url] = "/old-cdn/#{full_name}"
    fixed << { url: url, file: full_name, action: "renamed from #{short_name}" }
  else
    remaining << failure
  end
end

fixed.each do |f|
  puts "FIXED: #{f[:file]} (#{f[:action]})"
end

puts "\nFixed: #{fixed.size}"
puts "Remaining failures: #{remaining.size}"

File.write(MAPPING_FILE, JSON.pretty_generate(mapping))
File.write(FAILURES_FILE, JSON.pretty_generate(remaining))

# Replace URLs in codebase
TEXT_EXTENSIONS = %w[.rb .erb .haml .slim .js .ts .jsx .tsx .css .scss .sass .html .yml .yaml .json .md .txt].freeze

fixed_mapping = fixed.to_h { |f| [ f[:url], "/old-cdn/#{f[:file]}" ] }

if fixed_mapping.any?
  puts "\nReplacing URLs in codebase..."
  files_changed = 0
  total_replacements = 0

  `git ls-files -z`.split("\0").each do |path|
    next unless File.file?(path)
    next unless TEXT_EXTENSIONS.include?(File.extname(path).downcase)

    content = File.read(path, mode: "rb")
    next unless content.valid_encoding?

    replacements = 0
    fixed_mapping.each do |old_url, new_path|
      count = content.scan(old_url).size
      if count.positive?
        content.gsub!(old_url, new_path)
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

puts "\nDone."
