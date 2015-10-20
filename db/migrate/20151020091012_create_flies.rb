class CreateFlies < ActiveRecord::Migration
  def change
    create_table :flies do |t|
      t.text :chr1
      t.text :chr2
      t.text :chr3
      t.text :chr4
      t.integer :cross_id

      t.timestamps null: false
    end
  end
end
