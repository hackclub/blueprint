class AddFreeStickersClaimedToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :free_stickers_claimed, :boolean, default: false, null: false
  end
end
