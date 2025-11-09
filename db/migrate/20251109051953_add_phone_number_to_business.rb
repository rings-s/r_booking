class AddPhoneNumberToBusiness < ActiveRecord::Migration[8.1]
  def change
    add_column :businesses, :phone_number, :string
  end
end
