module Auth
  # Command: mint a signed token that carries a user id.
  class GenerateToken < Cqrs::Command
    def initialize(user_id:, expires_at: 24.hours.from_now)
      @user_id = user_id
      @expires_at = expires_at
    end

    def call
      TokenCodec.encode({ user_id: @user_id }, exp: @expires_at)
    end
  end
end
