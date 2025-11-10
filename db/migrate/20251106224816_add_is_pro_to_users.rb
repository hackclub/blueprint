class AddIsProToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :is_pro, :boolean, default: false
  end
end
