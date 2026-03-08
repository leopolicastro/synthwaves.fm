class CreateFavorites < ActiveRecord::Migration[8.1]
  def change
    create_table :favorites do |t|
      t.references :user, null: false, foreign_key: true
      t.string :favorable_type, null: false
      t.integer :favorable_id, null: false

      t.timestamps
    end
    add_index :favorites, [:user_id, :favorable_type, :favorable_id], unique: true
  end
end
