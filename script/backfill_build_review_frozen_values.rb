# Run with: rails runner script/backfill_build_review_frozen_values.rb

BuildReview.where(result: :approved, invalidated: false).find_each do |review|
  review.associate_journal_entries!

  frozen_duration = review.journal_entries.sum(:duration_seconds)
  frozen_count = review.journal_entries.count
  frozen_t = review.effective_tier

  review.update_columns(
    frozen_duration_seconds: frozen_duration,
    frozen_entry_count: frozen_count,
    frozen_tier: frozen_t,
    updated_at: Time.current
  )

  puts "Updated BuildReview ##{review.id}: #{frozen_duration}s, #{frozen_count} entries, tier #{frozen_t}"
end

puts "Done!"
