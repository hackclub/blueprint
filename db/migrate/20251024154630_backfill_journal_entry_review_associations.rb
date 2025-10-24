class BackfillJournalEntryReviewAssociations < ActiveRecord::Migration[8.0]
  def up
    # Backfill journal entries to approved design reviews
    # For each project with an approved admin design review, 
    # associate all journal entries created before that review
    
    execute <<-SQL.squish
      UPDATE journal_entries
      SET review_type = 'DesignReview',
          review_id = approved_reviews.id
      FROM (
        SELECT DISTINCT ON (dr.project_id) 
          dr.id,
          dr.project_id,
          dr.created_at
        FROM design_reviews dr
        WHERE dr.result = 0 
          AND dr.invalidated = false
          AND dr.admin_review = true
        ORDER BY dr.project_id, dr.created_at DESC
      ) AS approved_reviews
      WHERE journal_entries.project_id = approved_reviews.project_id
        AND journal_entries.created_at <= approved_reviews.created_at
        AND journal_entries.review_id IS NULL
    SQL
    
    # Note: Build reviews are new and likely have no data yet, 
    # so we don't backfill them. They will be associated going forward
    # when reviews are approved.
  end

  def down
    # Remove the polymorphic associations
    execute <<-SQL.squish
      UPDATE journal_entries
      SET review_type = NULL,
          review_id = NULL
      WHERE review_type IN ('DesignReview', 'BuildReview')
    SQL
  end
end
