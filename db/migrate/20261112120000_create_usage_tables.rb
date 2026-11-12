# Counts for the admin stats page. No IP addresses, browsers or paths are stored:
# one row per account per day, and one counter per page type per day.
class CreateUsageTables < ActiveRecord::Migration[8.1]
  def change
    create_table :activity_days do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.date :day, null: false
      t.integer :requests, null: false, default: 0
    end
    add_index :activity_days, %i[user_id day], unique: true
    add_index :activity_days, :day

    create_table :page_views do |t|
      t.date :day, null: false
      t.string :page, null: false
      t.boolean :signed_in, null: false
      t.integer :views, null: false, default: 0
    end
    add_index :page_views, %i[day page signed_in], unique: true
  end
end
