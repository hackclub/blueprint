class RevertBuildGuilds < ActiveRecord::Migration[8.0]
  def up
    drop_table :guild_signups, if_exists: true
    drop_table :guild_airtable_syncs, if_exists: true
    drop_table :guilds, if_exists: true
  end

  def down
    create_table :guilds do |t|
      t.string :name
      t.text :description
      t.string :city
      t.string :slack_channel_id
      t.integer :status
      t.float :latitude
      t.float :longitude
      t.string :country
      t.boolean :needs_review
      t.timestamps
    end
    add_index :guilds, [:city, :country], unique: true, name: "index_guilds_on_city_and_country"

    create_table :guild_signups do |t|
      t.references :user, null: false, foreign_key: true
      t.references :guild, null: false, foreign_key: true
      t.integer :role
      t.string :name
      t.string :email
      t.string :project_link
      t.text :ideas
      t.string :country
      t.text :attendee_activities
      t.timestamps
    end
    add_index :guild_signups, [:user_id, :guild_id], unique: true

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
