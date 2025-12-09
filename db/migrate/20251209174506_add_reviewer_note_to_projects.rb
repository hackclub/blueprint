class AddReviewerNoteToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :reviewer_note, :text
  end
end
