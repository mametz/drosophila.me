class CreateStocks < ActiveRecord::Migration
  def change
    create_table :stocks do |t|
      t.integer :number
      t.string :name
      t.integer :fly_id
      t.integer :lab_id
      t.integer :user_id
      t.text :comment
      t.date :date_established
      t.integer :room_id
      t.text :reference
      t.text :received_from

      t.timestamps null: false
    end
  end
end
