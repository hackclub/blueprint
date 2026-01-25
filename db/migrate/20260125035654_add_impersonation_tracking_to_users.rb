class AddImpersonationTrackingToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :last_impersonated_at, :datetime
    add_column :users, :last_impersonation_ended_at, :datetime
  end
end
