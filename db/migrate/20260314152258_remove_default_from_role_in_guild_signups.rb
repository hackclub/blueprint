class RemoveDefaultFromRoleInGuildSignups < ActiveRecord::Migration[8.0]
  def change
    change_column_default :guild_signups, :role, from: 0, to: nil
  end
end
