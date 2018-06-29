class AddStockborderToAccounts < ActiveRecord::Migration[5.0]
  def change
    add_column :accounts, :stock_border, :integer
  end
end
