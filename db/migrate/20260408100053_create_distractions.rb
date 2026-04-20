class CreateDistractions < ActiveRecord::Migration[8.1]
  def change
    create_table :distractions do |t|
      t.references :focus_session, null: false, foreign_key: true
      t.string :category
      t.datetime :occurred_at

      t.timestamps
    end
  end
end
