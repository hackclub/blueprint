class RecreateGuildsTables < ActiveRecord::Migration[8.0]
  def up
    # The original guild migrations (20260310-20260316) ran on production,
    # then the revert migration (20260316215225) dropped everything.
    # That revert migration was removed in the guilds PR, but the tables
    # are already gone. This migration re-creates them.

    unless table_exists?(:guilds)
      create_table :guilds do |t|
        t.string :name, null: false
        t.text :description
        t.string :city, null: false
        t.string :slack_channel_id
        t.integer :status, default: 0
        t.float :latitude
        t.float :longitude
        t.string :country, null: false
        t.boolean :needs_review, default: false

        t.timestamps
      end

      add_index :guilds, [ :city, :country ], unique: true, name: "index_guilds_on_city_and_country"
    end

    unless table_exists?(:guild_signups)
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

      add_index :guild_signups, [ :user_id, :guild_id ], unique: true
    end
  end

  def down
    drop_table :guild_signups, if_exists: true
    drop_table :guilds, if_exists: true
  end
end
