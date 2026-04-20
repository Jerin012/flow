class Note < ApplicationRecord
  belongs_to :user
  belongs_to :focus_session, optional: true

  validates :title, presence: true
  validates :content, presence: true
end
