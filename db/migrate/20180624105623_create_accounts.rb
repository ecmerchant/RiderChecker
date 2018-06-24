class CreateAccounts < ActiveRecord::Migration[5.0]
  def change
    create_table :accounts do |t|
      t.string :user
      t.string :seller_id
      t.string :secret_key
      t.string :aws_key
      t.string :cw_api_token
      t.string :cw_room_id

      t.timestamps
    end
  end
end
