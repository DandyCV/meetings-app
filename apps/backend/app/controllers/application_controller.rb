class ApplicationController < ActionController::API
  # Include this in controllers that require an authenticated user, e.g.:
  #   class Api::V1::MeetingsController < ApplicationController
  #     before_action :authenticate_user!
  #   end
  def authenticate_user!
    render_unauthorized and return unless current_user
  end

  # Composes the Auth and Users modules: Auth resolves the user id from the
  # bearer token, Users turns that id into a record.
  def current_user
    @current_user ||= begin
      user_id = Auth::VerifyToken.call(token: bearer_token)
      user_id && Users::FindUser.call(id: user_id)
    end
  end

  private

  def bearer_token
    header = request.headers["Authorization"]
    header&.split(" ")&.last
  end

  def render_unauthorized
    render json: { error: "Unauthorized" }, status: :unauthorized
  end
end
