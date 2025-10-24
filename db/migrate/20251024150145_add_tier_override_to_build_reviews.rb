class AddTierOverrideToBuildReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :build_reviews, :tier_override, :integer
  end
end
