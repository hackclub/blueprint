class AddFieldsToGuilds < ActiveRecord::Migration[8.0]
  def change
    # These columns were already added in CreateGuilds migration.
    # This migration is kept as a no-op to preserve migration history.
  end
end
