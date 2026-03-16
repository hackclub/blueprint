class AddCoordinatesToGuilds < ActiveRecord::Migration[8.0]
  def change
    add_column :guilds, :latitude, :float
    add_column :guilds, :longitude, :float
  end
end
