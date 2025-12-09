class AddFrozenReviewerNoteToBuildReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :build_reviews, :frozen_reviewer_note, :text
  end
end
