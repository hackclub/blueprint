# Backfill BuildReview and DesignReview journal associations and frozen fields
# Usage:
#   bin/rails reviews:backfill DRY_RUN=true
namespace :reviews do
  desc "Backfill BuildReview and DesignReview journal associations and frozen fields"
  task backfill: :environment do
    dry_run = ENV["DRY_RUN"].to_s.downcase == "true" || ENV["DRY_RUN"].to_s == "1"

    puts "Starting reviews backfill - dry_run=#{dry_run}"
    puts

    # Backfill BuildReviews
    build_reviews = BuildReview.where(result: :approved, invalidated: false)
    puts "Found #{build_reviews.count} approved BuildReviews to process"

    build_reviews.find_each do |review|
      puts "  BuildReview ##{review.id} (Project ##{review.project_id})"

      if dry_run
        entries = review.journal_entries_to_associate(up_to: review.created_at)
        puts "    Would associate #{entries.count} journal entries"
        puts "    Current: #{review.journal_entries.count} entries, #{review.frozen_duration_seconds} seconds"
        puts "    After: #{entries.sum(:duration_seconds)} seconds, multiplier: #{review.ticket_multiplier || BuildReview.default_multiplier_for_tier(review.effective_tier)}"
      else
        BuildReview.transaction do
          # Clear existing associations for this review
          JournalEntry.where(review: review).update_all(review_id: nil, review_type: nil)

          # Re-associate using the new logic with created_at as cutoff
          review.associate_journal_entries!(up_to: review.created_at)

          # Recompute frozen fields from current associations (don't call finalize_on_approve as it re-associates to Time.current)
          review.tier_override ||= review.project.tier
          review.ticket_multiplier ||= BuildReview.default_multiplier_for_tier(review.effective_tier)
          review.ticket_offset ||= 0

          frozen_duration = review.journal_entries.sum(:duration_seconds)
          frozen_count = review.journal_entries.count
          frozen_t = review.effective_tier

          review.update_columns(
            tier_override: review.tier_override,
            ticket_multiplier: review.ticket_multiplier,
            ticket_offset: review.ticket_offset,
            frozen_duration_seconds: frozen_duration,
            frozen_entry_count: frozen_count,
            frozen_tier: frozen_t,
            updated_at: Time.current
          )

          puts "    Associated #{review.journal_entries.count} journal entries"
          puts "    Frozen: #{review.frozen_duration_seconds}s, #{review.frozen_entry_count} entries"
          puts "    Tickets: #{review.tickets_awarded}"
        end
      end
    end

    puts

    # Backfill DesignReviews (only admin reviews)
    design_reviews = DesignReview.where(result: :approved, invalidated: false, admin_review: true)
    puts "Found #{design_reviews.count} approved admin DesignReviews to process"

    design_reviews.find_each do |review|
      puts "  DesignReview ##{review.id} (Project ##{review.project_id})"

      if dry_run
        entries = review.journal_entries_to_associate(up_to: review.created_at)
        puts "    Would associate #{entries.count} journal entries"
        puts "    Current: #{review.journal_entries.count} entries, #{review.frozen_duration_seconds} seconds"
        puts "    After: #{entries.sum(:duration_seconds)} seconds"
      else
        DesignReview.transaction do
          # Clear existing associations for this review
          JournalEntry.where(review: review).update_all(review_id: nil, review_type: nil)

          # Re-associate using the new logic with created_at as cutoff
          review.associate_journal_entries!(up_to: review.created_at)

          # Recompute frozen fields from current associations
          frozen_duration = review.journal_entries.sum(:duration_seconds)
          frozen_count = review.journal_entries.count

          review.update_columns(
            frozen_duration_seconds: frozen_duration,
            frozen_entry_count: frozen_count,
            frozen_funding_needed_cents: review.project.funding_needed_cents,
            frozen_tier: review.project.tier,
            updated_at: Time.current
          )

          puts "    Associated #{review.journal_entries.count} journal entries"
          puts "    Frozen: #{review.frozen_duration_seconds}s, #{review.frozen_entry_count} entries"
        end
      end
    end

    unless dry_run
      puts
      puts "Final pass: Recomputing frozen fields for all approved reviews..."

      # Recompute BuildReviews (only counts/durations, preserve historical frozen_tier)
      BuildReview.where(result: :approved, invalidated: false).find_each do |review|
        frozen_duration = review.journal_entries.sum(:duration_seconds)
        frozen_count = review.journal_entries.count

        review.update_columns(
          frozen_duration_seconds: frozen_duration,
          frozen_entry_count: frozen_count,
          updated_at: Time.current
        )
      end

      # Recompute DesignReviews (only counts/durations, preserve historical frozen_tier and frozen_funding)
      DesignReview.where(result: :approved, invalidated: false, admin_review: true).find_each do |review|
        frozen_duration = review.journal_entries.sum(:duration_seconds)
        frozen_count = review.journal_entries.count

        review.update_columns(
          frozen_duration_seconds: frozen_duration,
          frozen_entry_count: frozen_count,
          updated_at: Time.current
        )
      end

      puts "Final pass complete."
    end

    puts
    puts "Done. (dry_run=#{dry_run})"
  end
end
