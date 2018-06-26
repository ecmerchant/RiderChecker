class AddCheckedToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :checked, :boolean
  end
end
