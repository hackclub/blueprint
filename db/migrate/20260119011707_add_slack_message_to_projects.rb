class AddSlackMessageToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :slack_message, :string
  end
end
