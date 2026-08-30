module Api
  module V1
    class CurrentUserController < ApplicationController
      before_action :authenticate_user!

      # GET /api/v1/me
      def show
        render json: { id: current_user.id, email: current_user.email }
      end
    end
  end
end
