require "rails_helper"

RSpec.describe "Api::V1::Sessions", type: :request do
  let!(:user) do
    User.create!(email: "jane@example.com", password: "password123",
                 password_confirmation: "password123")
  end

  describe "POST /api/v1/sessions" do
    it "returns a token and the user on valid credentials" do
      post "/api/v1/sessions", params: { email: "jane@example.com", password: "password123" }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["token"]).to be_present
      expect(body["user"]).to eq({ "id" => user.id, "email" => user.email })
    end

    it "is case-insensitive on email" do
      post "/api/v1/sessions", params: { email: "JANE@example.com", password: "password123" }

      expect(response).to have_http_status(:ok)
    end

    it "rejects an incorrect password" do
      post "/api/v1/sessions", params: { email: "jane@example.com", password: "wrong" }

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["error"]).to be_present
    end

    it "rejects an unknown email" do
      post "/api/v1/sessions", params: { email: "nobody@example.com", password: "password123" }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
