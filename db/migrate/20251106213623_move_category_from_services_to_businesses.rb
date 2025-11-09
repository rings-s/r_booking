class MoveCategoryFromServicesToBusinesses < ActiveRecord::Migration[8.1]
  def change
    # Add category_id to businesses
    add_reference :businesses, :category, foreign_key: true

    # Remove category_id from services
    remove_reference :services, :category, foreign_key: true
  end
end
