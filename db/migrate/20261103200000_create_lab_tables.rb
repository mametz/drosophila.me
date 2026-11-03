class CreateLabTables < ActiveRecord::Migration[8.1]
  def change
    create_table :rooms do |t|
      t.string :name, null: false
      t.integer :temperature
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    create_table :crosses do |t|
      t.references :user, null: false, foreign_key: true
      t.bigint :male_fly_id
      t.bigint :female_fly_id
      t.bigint :parent_id
      t.string :slug, null: false
      t.text :description
      t.text :balancers, null: false, default: ""
      t.text :lethal, null: false, default: ""
      t.date :crossdate, null: false
      t.boolean :shared, null: false, default: true
      t.timestamps
    end
    add_index :crosses, :slug, unique: true
    add_index :crosses, :male_fly_id
    add_index :crosses, :female_fly_id
    add_index :crosses, :parent_id
    add_foreign_key :crosses, :crosses, column: :parent_id, on_delete: :nullify

    create_table :flies do |t|
      t.text :chr1, null: false
      t.text :chr2, null: false
      t.text :chr3, null: false
      t.text :chr4, null: false
      t.bigint :cross_id
      t.timestamps
    end
    add_index :flies, :cross_id
    add_foreign_key :flies, :crosses, on_delete: :nullify
    add_foreign_key :crosses, :flies, column: :male_fly_id
    add_foreign_key :crosses, :flies, column: :female_fly_id

    create_table :stocks do |t|
      t.integer :number
      t.string :name
      t.references :fly, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :room, foreign_key: { on_delete: :nullify }
      t.text :comment
      t.date :date_established
      t.text :reference
      t.text :received_from
      t.timestamps
    end
  end
end
