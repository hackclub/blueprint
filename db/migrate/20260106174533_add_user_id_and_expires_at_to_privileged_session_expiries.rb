class AddUserIdAndExpiresAtToPrivilegedSessionExpiries < ActiveRecord::Migration[8.0]
  def change
    PrivilegedSessionExpiry.delete_all
    add_reference :privileged_session_expiries, :user, null: false, foreign_key: true
    add_column :privileged_session_expiries, :expires_at, :datetime, null: false
    remove_index :privileged_session_expiries, :user_id
    add_index :privileged_session_expiries, :user_id, unique: true
    remove_column :privileged_session_expiries, :invalidated_at, :datetime
  end
end
