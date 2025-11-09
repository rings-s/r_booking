class CreateQueueTickets < ActiveRecord::Migration[8.1]
  def change
    create_table :queue_tickets do |t|
      t.references :booking, null: false, foreign_key: true
      t.integer :position
      t.integer :status
      t.datetime :issued_at

      t.timestamps
    end
  end
end
