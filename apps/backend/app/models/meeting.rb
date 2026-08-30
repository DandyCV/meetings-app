class Meeting < ApplicationRecord
  belongs_to :user

  validates :title, presence: true
  validates :starts_at, presence: true

  scope :recent_first, -> { order(starts_at: :desc) }
end
