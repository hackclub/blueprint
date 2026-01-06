class AddShopkeeperToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :shopkeeper, :boolean, default: false, null: false
  end
end
