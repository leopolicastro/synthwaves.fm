class CreateInternetRadioCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :internet_radio_categories do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :stations_count, default: 0

      t.timestamps
    end

    add_index :internet_radio_categories, :name, unique: true
    add_index :internet_radio_categories, :slug, unique: true
  end
end
