module Api
  module V1
    class RegistrationsController < ApplicationController
      # POST /api/v1/registrations
      def create
        result = Users::RegisterUser.call(
          email: registration_params[:email],
          password: registration_params[:password],
          password_confirmation: registration_params[:password_confirmation]
        )

        if result.success?
          user = result.value
          render json: { token: Auth::GenerateToken.call(user_id: user.id), user: user_json(user) },
                 status: :created
        else
          render json: { errors: result.errors }, status: :unprocessable_content
        end
      end

      private

      def registration_params
        params.require(:user).permit(:email, :password, :password_confirmation)
      end

      def user_json(user)
        { id: user.id, email: user.email }
      end
    end
  end
end
