class CreateGuildAirtableSyncs < ActiveRecord::Migration[8.0]
  def change
    create_table :guild_airtable_syncs do |t|
      t.string :airtable_id
      t.string :record_identifier
      t.datetime :last_synced_at
      t.string :synced_attributes_hash

      t.timestamps
    end
    add_index :guild_airtable_syncs, :record_identifier, unique: true
  end
end
