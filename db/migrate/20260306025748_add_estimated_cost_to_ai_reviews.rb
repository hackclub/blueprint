class AddEstimatedCostToAiReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_reviews, :estimated_cost_cents, :integer
  end
end
