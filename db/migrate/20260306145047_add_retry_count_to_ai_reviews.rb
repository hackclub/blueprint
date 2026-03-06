class AddRetryCountToAiReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_reviews, :retry_count, :integer, default: 0, null: false
  end
end
