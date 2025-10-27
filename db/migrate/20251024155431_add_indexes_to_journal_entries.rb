class AddIndexesToJournalEntries < ActiveRecord::Migration[8.0]
  def change
    # Index for polymorphic review association lookups
    add_index :journal_entries, [ :review_type, :review_id ]

    # Partial index for finding unreviewed entries by project
    add_index :journal_entries, [ :project_id, :created_at ],
              where: "review_id IS NULL",
              name: "index_journal_entries_unreviewed_by_project"
  end
end
