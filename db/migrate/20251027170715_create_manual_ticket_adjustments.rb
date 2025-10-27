class CreateManualTicketAdjustments < ActiveRecord::Migration[8.0]
  def change
    create_table :manual_ticket_adjustments do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :adjustment
      t.string :internal_reason

      t.timestamps
    end
  end
end
