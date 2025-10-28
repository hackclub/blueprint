class AddSkipGhSyncToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :skip_gh_sync, :boolean, default: false
  end
end
