require "jwt"

module Auth
  # Low-level JSON Web Token encode/decode. Internal to the Auth module; callers
  # go through Auth::GenerateToken / Auth::VerifyToken.
  module TokenCodec
    ALGORITHM = "HS256".freeze

    module_function

    def encode(payload, exp:)
      JWT.encode(payload.merge(exp: exp.to_i), secret_key, ALGORITHM)
    end

    def decode(token)
      decoded = JWT.decode(token, secret_key, true, algorithm: ALGORITHM)[0]
      ActiveSupport::HashWithIndifferentAccess.new(decoded)
    rescue JWT::DecodeError
      nil
    end

    def secret_key
      Rails.application.secret_key_base
    end
  end
end
