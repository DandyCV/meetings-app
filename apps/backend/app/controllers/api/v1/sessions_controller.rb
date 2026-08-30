module Api
  module V1
    class SessionsController < ApplicationController
      # POST /api/v1/sessions
      def create
        user = Users::AuthenticateUser.call(email: params[:email], password: params[:password])

        if user
          render json: { token: Auth::GenerateToken.call(user_id: user.id), user: user_json(user) },
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
