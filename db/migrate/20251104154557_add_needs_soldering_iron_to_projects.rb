class AddNeedsSolderingIronToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :needs_soldering_iron, :boolean, default: false, null: false
  end
end
