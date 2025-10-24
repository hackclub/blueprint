class AddHoursOverrideToBuildReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :build_reviews, :hours_override, :float
  end
end
