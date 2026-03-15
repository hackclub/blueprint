class AddCountryAndNeedsReviewToGuilds < ActiveRecord::Migration[8.0]
  def change
    add_column :guilds, :country, :string
    add_column :guilds, :needs_review, :boolean
  end
end
