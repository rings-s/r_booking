class CreateBusinesses < ActiveRecord::Migration[8.1]
  def change
    create_table :businesses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.text :description
      t.string :location
      t.time :open_time
      t.time :close_time

      t.timestamps
    end
  end
end
