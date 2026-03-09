class CreateEPGProgrammes < ActiveRecord::Migration[8.1]
  def change
    create_table :epg_programmes do |t|
      t.string :channel_id, null: false
      t.string :title, null: false
      t.string :subtitle
      t.text :description
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.timestamps
    end

    add_index :epg_programmes, [:channel_id, :starts_at]
    add_index :epg_programmes, :ends_at
  end
end
