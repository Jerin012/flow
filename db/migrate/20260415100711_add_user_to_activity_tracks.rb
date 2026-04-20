class AddUserToActivityTracks < ActiveRecord::Migration[8.1]
  def change
    add_reference :activity_tracks, :user, null: false, foreign_key: true
  end
end
