class CreateGuilds < ActiveRecord::Migration[8.0]
  def change
    create_table :guilds do |t|
      t.string :name
      t.text :description
      t.string :city, null: false
      t.string :slack_channel_id
      t.integer :status, default: 0

      t.timestamps
    end

    # Unique index on (city, country) is added in a later migration (20260316122440)
  end
end
