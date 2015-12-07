class CreateRooms < ActiveRecord::Migration
  def change
    create_table :rooms do |t|
      t.string :name
      t.integer :temperature
      t.integer :user_id
      t.integer :lab_id

      t.timestamps null: false
    end
  end
end
