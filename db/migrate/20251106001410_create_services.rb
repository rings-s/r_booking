class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.string :name, null: false
      t.text :description
      t.integer :duration, null: false  # in minutes
      t.decimal :price, precision: 10, scale: 2, null: false
      t.references :business, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true

      t.timestamps
    end

    add_index :services, [:business_id, :name], unique: true
  end
end
