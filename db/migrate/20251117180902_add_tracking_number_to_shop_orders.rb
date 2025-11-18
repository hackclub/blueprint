class AddTrackingNumberToShopOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :shop_orders, :tracking_number, :string
  end
end
