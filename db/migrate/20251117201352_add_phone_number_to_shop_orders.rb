class AddPhoneNumberToShopOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :shop_orders, :phone_number, :string
  end
end
