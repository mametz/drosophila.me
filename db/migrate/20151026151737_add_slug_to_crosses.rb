class AddSlugToCrosses < ActiveRecord::Migration
  def change
    add_column :crosses, :slug, :string
  end
end
