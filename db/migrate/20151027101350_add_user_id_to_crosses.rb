class AddUserIdToCrosses < ActiveRecord::Migration
  def change
    add_column :crosses, :user_id, :integer
  end
end
