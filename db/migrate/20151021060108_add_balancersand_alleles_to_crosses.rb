class AddBalancersandAllelesToCrosses < ActiveRecord::Migration
  def change
    add_column :crosses, :balancers, :text
    add_column :crosses, :lethal, :text
  end
end
