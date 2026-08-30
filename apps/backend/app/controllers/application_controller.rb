class ApplicationController < ActionController::API
  # Include this in controllers that require an authenticated user, e.g.:
  #   class Api::V1::MeetingsController < ApplicationController
  #     before_action :authenticate_user!
  #   end
  def authenticate_user!
    render_unauthorized and return unless current_user
  end

  def current_user
    @current_user ||= user_from_token
  end

  private

  def user_from_token
    token = bearer_token
    return nil unless token

    payload = JsonWebToken.decode(token)
    return nil unless payload

    User.find_by(id: payload[:user_id])
  end

  def bearer_token
    header = request.headers["Authorization"]
    header&.split(" ")&.last
  end

  def render_unauthorized
    render json: { error: "Unauthorized" }, status: :unauthorized
  end
end
