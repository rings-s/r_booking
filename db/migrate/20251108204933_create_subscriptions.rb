class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.string :payment_id
      t.string :moyasar_payment_id
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, default: 'SAR', null: false
      t.datetime :trial_ends_at
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.datetime :cancelled_at

      t.timestamps
    end

    add_index :subscriptions, :status
    add_index :subscriptions, :moyasar_payment_id
    add_index :subscriptions, [:user_id, :status]
  end
end
