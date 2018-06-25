class AddJridenToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :jriden, :boolean
  end
end
