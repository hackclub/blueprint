class CreateBuildReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :build_reviews do |t|
      t.references :reviewer, null: false, foreign_key: { to_table: :users }
      t.references :project, null: false, foreign_key: true
      t.boolean :admin_review
      t.string :reason
      t.text :feedback
      t.integer :result
      t.boolean :invalidated, default: false
      t.integer :frozen_duration_seconds
      t.integer :frozen_entry_count
      t.integer :frozen_tier
      t.float :ticket_multiplier
      t.integer :ticket_offset

      t.timestamps
    end

    add_index :build_reviews,
              [ :reviewer_id, :project_id ],
              unique: true,
              where: "invalidated = false"
  end
end
