class AddRequestIpToOneTimePasswords < ActiveRecord::Migration[8.0]
  def change
    add_column :one_time_passwords, :request_ip, :string
  end
end
