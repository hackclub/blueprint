class AddFirstSyncedToAirtableToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :first_synced_to_airtable, :boolean, default: false, null: false
  end
end
