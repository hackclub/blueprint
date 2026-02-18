class CreateAiReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_reviews do |t|
      t.references :project, null: false, foreign_key: true
      t.string :review_phase, null: false
      t.string :status, null: false, default: "queued"
      t.jsonb :analysis, default: {}
      t.text :raw_response
      t.text :error_message
      t.integer :prompt_tokens
      t.integer :completion_tokens
      t.integer :total_tokens
      t.string :model_used
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :ai_reviews, [ :project_id, :review_phase ]
    add_index :ai_reviews, :status
  end
end
