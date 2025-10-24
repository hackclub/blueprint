class AddReviewToJournalEntries < ActiveRecord::Migration[8.0]
  def change
    add_reference :journal_entries, :review, polymorphic: true, null: true, index: true
  end
end
