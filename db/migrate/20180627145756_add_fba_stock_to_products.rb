class AddFbaStockToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :fba_stock, :integer
    add_column :products, :is_cart_price, :boolean
  end
end
