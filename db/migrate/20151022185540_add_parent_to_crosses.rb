class AddParentToCrosses < ActiveRecord::Migration
  def change
    add_column :crosses, :parent, :integer
  end
end
