class AddFieldsToGuilds < ActiveRecord::Migration[8.0]
  def change
    add_column :guilds, :city, :string
    add_column :guilds, :slack_channel_id, :string
    add_column :guilds, :status, :integer, default: 0
    add_index :guilds, :city, unique: true
  end
end
