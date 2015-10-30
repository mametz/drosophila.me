class AddCrossDateToCrosses < ActiveRecord::Migration
  def change
    add_column :crosses, :crossdate, :date
  end
end
