class CreateReflections < ActiveRecord::Migration[8.1]
  def change
    create_table :reflections do |t|
      t.references :user, null: false, foreign_key: true
      t.date :date
      t.text :what_went_well
      t.text :main_distractions
      t.text :improvements

      t.timestamps
    end
  end
end
