module Users
  # Query: return the user matching an email/password pair, or nil when the
  # email is unknown or the password is wrong.
  class AuthenticateUser < Cqrs::Query
    def initialize(email:, password:)
      @email = email
      @password = password
    end

    def call
      user = User.find_by(email: @email.to_s.strip.downcase)
      return nil unless user&.authenticate(@password.to_s)

      user
    end
  end
end
