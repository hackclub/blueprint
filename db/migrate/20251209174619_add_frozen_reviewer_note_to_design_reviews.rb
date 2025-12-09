class AddFrozenReviewerNoteToDesignReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :design_reviews, :frozen_reviewer_note, :text
  end
end
