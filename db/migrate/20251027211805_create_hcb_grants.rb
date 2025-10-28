class CreateHcbGrants < ActiveRecord::Migration[8.0]
  def change
    create_table :hcb_grants do |t|
      t.string :org_id, null: false
      t.string :grant_id, null: false
      t.string :status
      t.integer :initial_amount_cents
      t.integer :balance_cents
      t.string :to_user_name
      t.text :to_user_avatar
      t.text :for_reason
      t.datetime :issued_at
      t.string :source_url
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.datetime :last_synced_at
      t.integer :sync_failures_count, null: false, default: 0
      t.text :last_sync_error
      t.datetime :soft_deleted_at

      t.timestamps
    end
    add_index :hcb_grants, [ :org_id, :grant_id ], unique: true
    add_index :hcb_grants, :last_seen_at
    add_index :hcb_grants, :soft_deleted_at
  end
end
