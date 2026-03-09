class CreateIPTVCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :iptv_categories do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :channels_count, default: 0

      t.timestamps
    end

    add_index :iptv_categories, :name, unique: true
    add_index :iptv_categories, :slug, unique: true
  end
end
