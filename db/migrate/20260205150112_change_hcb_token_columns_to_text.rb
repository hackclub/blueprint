class ChangeHcbTokenColumnsToText < ActiveRecord::Migration[8.0]
  def change
    change_column :users, :hcb_access_token, :text
    change_column :users, :hcb_refresh_token, :text
  end
end
