class AddCityCountryIndexToGuilds < ActiveRecord::Migration[8.0]
  def change
    add_index :guilds, [ :city, :country ], unique: true, name: "index_guilds_on_city_and_country"
  end
end
