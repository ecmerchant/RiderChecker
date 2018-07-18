class AddRoomid2ToAccounts < ActiveRecord::Migration[5.0]
  def change
    add_column :accounts, :cw_room_id2, :string
  end
end
