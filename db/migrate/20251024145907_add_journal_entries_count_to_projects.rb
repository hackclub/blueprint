class AddJournalEntriesCountToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :journal_entries_count, :integer, default: 0, null: false

    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE projects
          SET journal_entries_count = (
            SELECT COUNT(*)
            FROM journal_entries
            WHERE journal_entries.project_id = projects.id
          )
        SQL
      end
    end
  end
end
