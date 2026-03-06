class AddStepsToAiReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_reviews, :steps, :jsonb, default: [], null: false
  end
end
