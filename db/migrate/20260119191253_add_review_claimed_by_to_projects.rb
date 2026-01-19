class AddReviewClaimedByToProjects < ActiveRecord::Migration[8.0]
  def change
    add_reference :projects, :design_review_claimed_by, foreign_key: { to_table: :users }
    add_reference :projects, :build_review_claimed_by, foreign_key: { to_table: :users }
  end
end
