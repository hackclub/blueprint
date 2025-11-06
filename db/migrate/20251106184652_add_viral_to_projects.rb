class AddViralToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :viral, :boolean, default: false, null: false
  end
end
