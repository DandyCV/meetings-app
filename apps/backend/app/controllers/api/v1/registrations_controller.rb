module Api
  module V1
    class RegistrationsController < ApplicationController
      # POST /api/v1/registrations
      def create
        user = User.new(registration_params)

        if user.save
          render json: { token: JsonWebToken.encode({ user_id: user.id }), user: user_json(user) },
                 status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_content
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
