class AddDescriptionToCrosses < ActiveRecord::Migration
  def change
    add_column :crosses, :description, :text
  end
end
