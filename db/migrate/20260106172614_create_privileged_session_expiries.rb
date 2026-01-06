class CreatePrivilegedSessionExpiries < ActiveRecord::Migration[8.0]
  def change
    create_table :privileged_session_expiries do |t|
      t.datetime :invalidated_at

      t.timestamps
    end
  end
end
