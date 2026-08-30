module Auth
  # Query: resolve the user id carried by a token, or nil when the token is
  # missing, malformed, tampered with, or expired.
  class VerifyToken < Cqrs::Query
    def initialize(token:)
      @token = token
    end

    def call
      return nil if @token.blank?

      payload = TokenCodec.decode(@token)
      payload && payload[:user_id]
    end
  end
end
