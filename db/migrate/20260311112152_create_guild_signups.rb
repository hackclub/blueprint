class CreateGuildSignups < ActiveRecord::Migration[8.0]
  def change
    create_table :guild_signups do |t|
      t.references :user, null: false, foreign_key: true
      t.references :guild, null: false, foreign_key: true
      t.integer :role, default: 0   # 0 = organizer, 1 = attendee
      t.string :name
      t.string :email
      t.string :project_link
      t.text :ideas

      t.timestamps
    end

    # Prevent duplicate signups by the same user for the same guild
    add_index :guild_signups, [ :user_id, :guild_id ], unique: true
  end
end
