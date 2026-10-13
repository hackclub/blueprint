class CreatePrivacyTokenUses < ActiveRecord::Migration[8.1]
  def change
    create_table :privacy_token_uses do |t|
      t.string :jti, null: false
      t.datetime :used_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end
    add_index :privacy_token_uses, :jti, unique: true
    add_index :privacy_token_uses, :used_at
  end
end
