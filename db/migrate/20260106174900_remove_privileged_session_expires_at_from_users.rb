class RemovePrivilegedSessionExpiresAtFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :privileged_session_expires_at, :datetime
  end
end
