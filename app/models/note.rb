class Note < ApplicationRecord
  belongs_to :user
  belongs_to :focus_session, optional: true

  validates :title, presence: true
  validates :content, presence: true

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }

  def deleted?
    deleted_at.present?
  end
end
