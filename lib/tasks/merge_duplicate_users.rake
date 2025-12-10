# frozen_string_literal: true

namespace :users do
  desc "Merge duplicate users by case-insensitive email. Set DRY_RUN=false to apply changes."
  task merge_duplicates: :environment do
    dry_run = ENV.fetch("DRY_RUN", "true") != "false"
    interactive = ENV.fetch("INTERACTIVE", "false") == "true"

    puts "Starting duplicate user merge..."
    puts "Mode: #{dry_run ? 'DRY RUN' : 'LIVE RUN'}"
    puts "Interactive: #{interactive ? 'YES' : 'NO'}"
    puts

    merger = DuplicateUserMerger.new(dry_run: dry_run, interactive: interactive)
    merger.run
    merger.print_report

    filename = merger.save_report
    puts
    puts "Report saved to: #{filename}"
  end
end
