class CreateProducts < ActiveRecord::Migration[5.0]
  def change
    create_table :products do |t|
      t.string :sku
      t.string :asin
      t.integer :seller_num
      t.integer :price
      t.boolean :riden

      t.timestamps
    end
  end
end
