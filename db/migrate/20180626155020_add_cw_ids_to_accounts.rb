class AddCwIdsToAccounts < ActiveRecord::Migration[5.0]
  def change
    add_column :accounts, :cw_ids, :string
  end
end
