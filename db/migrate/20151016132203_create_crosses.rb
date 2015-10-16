class CreateCrosses < ActiveRecord::Migration
  def change
    create_table :crosses do |t|
      t.integer :male_id
      t.integer :female_id
      t.string :link

      t.timestamps null: false
    end
  end
end
