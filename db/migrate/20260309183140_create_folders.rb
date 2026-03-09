class CreateFolders < ActiveRecord::Migration[8.1]
  def change
    create_table :folders do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description

      t.timestamps
    end
    add_index :folders, [:user_id, :name], unique: true
  end
end
