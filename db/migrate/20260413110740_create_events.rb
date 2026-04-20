class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.references :session, null: false, foreign_key: true
      t.string :event_type
      t.datetime :timestamp
      t.json :metadata

      t.timestamps
    end
  end
end
