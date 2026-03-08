class CreatePlayHistories < ActiveRecord::Migration[8.1]
  def change
    create_table :play_histories do |t|
      t.references :user, null: false, foreign_key: true
      t.references :track, null: false, foreign_key: true
      t.datetime :played_at, null: false

      t.timestamps
    end
    add_index :play_histories, [:user_id, :played_at]
  end
end
