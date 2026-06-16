class AddBypassSubmissionLockToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :bypass_submission_lock, :boolean, default: false, null: false
  end
end
