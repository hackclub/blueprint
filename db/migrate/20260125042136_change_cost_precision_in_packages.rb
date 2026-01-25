class ChangeCostPrecisionInPackages < ActiveRecord::Migration[8.0]
  def change
    change_column :packages, :cost, :decimal, precision: 10, scale: 2
  end
end
