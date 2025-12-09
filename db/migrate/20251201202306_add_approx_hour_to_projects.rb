class AddApproxHourToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :approx_hour, :decimal, precision: 3, scale: 1
  end
end
