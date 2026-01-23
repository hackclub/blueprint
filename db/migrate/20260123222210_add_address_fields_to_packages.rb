class AddAddressFieldsToPackages < ActiveRecord::Migration[8.0]
  def change
    add_column :packages, :recipient_email, :string
    add_column :packages, :address_line_1, :string
    add_column :packages, :address_line_2, :string
    add_column :packages, :city, :string
    add_column :packages, :state, :string
    add_column :packages, :postal_code, :string
    add_column :packages, :country, :string
  end
end
