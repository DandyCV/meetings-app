module Users
  class User < ApplicationRecord
    self.table_name = "users"

    has_secure_password

    has_many :meetings, class_name: "Meeting", foreign_key: "user_id",
                        inverse_of: :user, dependent: :destroy

    normalizes :email, with: ->(email) { email.strip.downcase }

    validates :email, presence: true,
                      uniqueness: true,
                      format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :password, length: { minimum: 8 }, allow_nil: true
  end
end
