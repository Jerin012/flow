class User < ApplicationRecord
  has_secure_password

  has_many :focus_sessions
  has_many :activity_tracks
  has_many :notes
  has_many :reflections

  validates :email, presence: true, uniqueness: true
end
