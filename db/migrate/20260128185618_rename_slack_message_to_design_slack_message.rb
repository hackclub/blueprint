class RenameSlackMessageToDesignSlackMessage < ActiveRecord::Migration[8.0]
  def change
    rename_column :projects, :slack_message, :design_slack_message
    add_column :projects, :build_slack_message, :string
  end
end
