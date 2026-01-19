class AddReviewClaimedAtToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :design_review_claimed_at, :datetime
    add_column :projects, :build_review_claimed_at, :datetime
  end
end
