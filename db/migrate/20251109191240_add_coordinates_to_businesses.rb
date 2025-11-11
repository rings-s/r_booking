class AddCoordinatesToBusinesses < ActiveRecord::Migration[8.1]
  def change
    add_column :businesses, :latitude, :decimal, precision: 10, scale: 6
    add_column :businesses, :longitude, :decimal, precision: 10, scale: 6
  end
end
