module Users
  # Command: create a new account. Returns a Cqrs::Result wrapping either the
  # persisted user or the validation error messages.
  class RegisterUser < Cqrs::Command
    def initialize(email:, password:, password_confirmation:)
      @email = email
      @password = password
      @password_confirmation = password_confirmation
    end

    def call
      user = User.new(
        email: @email,
        password: @password,
        password_confirmation: @password_confirmation
      )

      if user.save
        Cqrs::Result.success(user)
      else
        Cqrs::Result.failure(user.errors.full_messages)
      end
    end
  end
end
