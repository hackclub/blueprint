class AddHcbOauthToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :hcb_integration_enabled, :boolean, default: false, null: false
    add_column :users, :hcb_access_token, :string
    add_column :users, :hcb_refresh_token, :string
    add_column :users, :hcb_token_expires_at, :datetime

    add_index :users, :hcb_integration_enabled,
              unique: true,
              where: "hcb_integration_enabled = true",
              name: "index_users_unique_hcb_integration_enabled"
  end
end
