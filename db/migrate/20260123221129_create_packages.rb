class CreatePackages < ActiveRecord::Migration[8.0]
  def change
    create_table :packages do |t|
      t.references :trackable, polymorphic: true, null: false
      t.datetime :sent_at
      t.string :recipient_name
      t.string :tracking_number
      t.decimal :cost
      t.string :carrier
      t.string :service

      t.timestamps
    end
  end
end
