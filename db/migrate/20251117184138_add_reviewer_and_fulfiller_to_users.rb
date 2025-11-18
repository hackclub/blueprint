class AddReviewerAndFulfillerToUsers < ActiveRecord::Migration[8.0]
  def up
    # Add new boolean columns if they don't exist
    add_column :users, :admin, :boolean, default: false, null: false unless column_exists?(:users, :admin)
    add_column :users, :reviewer, :boolean, default: false, null: false unless column_exists?(:users, :reviewer)
    add_column :users, :fulfiller, :boolean, default: false, null: false unless column_exists?(:users, :fulfiller)

    # Migrate existing roles to the new boolean columns
    if column_exists?(:users, :role) && !column_exists?(:users, :old_role)
      # Rename role to old_role to preserve data
      rename_column :users, :role, :old_role

      # Use raw SQL to avoid any model scopes
      execute("UPDATE users SET admin = TRUE WHERE old_role = 1")
      execute("UPDATE users SET reviewer = TRUE WHERE old_role = 2")

      # Keep old_role for now - will be removed in safety migration after verification
    end
  end

  def down
    # Restore from old_role if it exists, otherwise from boolean columns
    if column_exists?(:users, :old_role)
      # Simply rename back
      rename_column :users, :old_role, :role
    else
      # Reconstruct from boolean columns
      add_column :users, :role, :integer, default: 0, null: false unless column_exists?(:users, :role)

      # Use SQL to avoid scopes - admin takes precedence
      execute("UPDATE users SET role = 1 WHERE admin = TRUE")
      execute("UPDATE users SET role = 2 WHERE reviewer = TRUE AND admin = FALSE")
      execute("UPDATE users SET role = 0 WHERE admin = FALSE AND reviewer = FALSE")
    end

    # Remove the boolean columns
    remove_column :users, :admin if column_exists?(:users, :admin)
    remove_column :users, :reviewer if column_exists?(:users, :reviewer)
    remove_column :users, :fulfiller if column_exists?(:users, :fulfiller)
  end
end
