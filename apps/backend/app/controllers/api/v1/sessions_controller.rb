module Api
  module V1
    class SessionsController < ApplicationController
      # POST /api/v1/sessions
      def create
        user = User.find_by(email: params[:email].to_s.strip.downcase)

        if user&.authenticate(params[:password].to_s)
          render json: { token: JsonWebToken.encode({ user_id: user.id }), user: user_json(user) },
                 status: :ok
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      private

      def user_json(user)
        { id: user.id, email: user.email }
      end
    end
  end
end
