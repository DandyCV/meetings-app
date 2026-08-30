class Meeting < ApplicationRecord
  belongs_to :user, class_name: "Users::User", inverse_of: :meetings

  validates :title, presence: true
  validates :starts_at, presence: true

  scope :recent_first, -> { order(starts_at: :desc) }
end
