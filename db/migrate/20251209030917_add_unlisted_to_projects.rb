class AddUnlistedToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :unlisted, :boolean, default: false, null: false
  end
end
