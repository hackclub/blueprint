class AddIdentityVaultRefreshFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :identity_vault_refresh_token, :text
    add_column :users, :identity_vault_token_expires_at, :datetime
  end
end
