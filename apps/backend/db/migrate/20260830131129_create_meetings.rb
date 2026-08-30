class CreateMeetings < ActiveRecord::Migration[8.1]
  def change
    create_table :meetings do |t|
      t.string :title, null: false
      t.text :description
      t.datetime :starts_at, null: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
