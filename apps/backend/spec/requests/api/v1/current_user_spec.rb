require "rails_helper"

RSpec.describe "Api::V1::CurrentUser", type: :request do
  let(:user) do
    User.create!(email: "jane@example.com", password: "password123",
                 password_confirmation: "password123")
  end

  describe "GET /api/v1/me" do
    it "returns the current user for a valid token" do
      token = JsonWebToken.encode({ user_id: user.id })

      get "/api/v1/me", headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq({ "id" => user.id, "email" => user.email })
    end

    it "rejects a missing token" do
      get "/api/v1/me"

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects an invalid token" do
      get "/api/v1/me", headers: { "Authorization" => "Bearer not-a-real-token" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects an expired token" do
      token = JsonWebToken.encode({ user_id: user.id }, exp: 1.hour.ago)

      get "/api/v1/me", headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
