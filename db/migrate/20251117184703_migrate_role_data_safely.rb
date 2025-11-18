class MigrateRoleDataSafely < ActiveRecord::Migration[8.0]
  def up
    # This is a safety migration to ensure no data was lost
    if column_exists?(:users, :old_role)
      say "Verifying data migration from old_role..."

      # Double-check the migration using raw SQL to avoid scopes
      execute("UPDATE users SET admin = TRUE WHERE old_role = 1 AND admin = FALSE")
      execute("UPDATE users SET reviewer = TRUE WHERE old_role = 2 AND reviewer = FALSE")

      # Verify counts match using select_value for adapter safety
      admin_count = select_value("SELECT COUNT(*) AS count FROM users WHERE admin = TRUE").to_i
      reviewer_count = select_value("SELECT COUNT(*) AS count FROM users WHERE reviewer = TRUE").to_i
      old_admin_count = select_value("SELECT COUNT(*) AS count FROM users WHERE old_role = 1").to_i
      old_reviewer_count = select_value("SELECT COUNT(*) AS count FROM users WHERE old_role = 2").to_i

      # Check for unexpected old_role values
      unexpected = select_value("SELECT COUNT(*) AS count FROM users WHERE old_role NOT IN (0,1,2) OR old_role IS NULL").to_i
      say "WARNING: #{unexpected} users had unexpected old_role values" if unexpected > 0

      # Verify parity - counts must match exactly
      if admin_count != old_admin_count || reviewer_count != old_reviewer_count
        raise ActiveRecord::IrreversibleMigration,
          "Migration mismatch! Admins: #{admin_count}/#{old_admin_count}, Reviewers: #{reviewer_count}/#{old_reviewer_count}"
      end

      if admin_count == 0
        raise ActiveRecord::IrreversibleMigration, "No admin users found - data may have been lost!"
      end

      say "✓ Verified: #{admin_count} admin(s) and #{reviewer_count} reviewer(s) - perfect match!"
      say "Removing old_role column after successful verification..."
      remove_column :users, :old_role
    else
      say "No old_role column found - migration already completed or not needed"
    end
  end

  def down
    # Nothing to do
  end
end
