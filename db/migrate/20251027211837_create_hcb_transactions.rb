class CreateHcbTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :hcb_transactions do |t|
      t.references :hcb_grant, null: false, foreign_key: true
      t.string :org_id, null: false
      t.string :transaction_id, null: false
      t.string :status
      t.integer :amount_cents
      t.integer :receipt_count
      t.text :memo
      t.datetime :hcb_created_at
      t.string :source_url
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.datetime :last_synced_at

      t.timestamps
    end
    add_index :hcb_transactions, [:org_id, :transaction_id], unique: true
    add_index :hcb_transactions, :last_seen_at
  end
end
