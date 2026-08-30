require "rails_helper"

RSpec.describe "Api::V1::Registrations", type: :request do
  describe "POST /api/v1/registrations" do
    it "creates a user and returns a token" do
      expect {
        post "/api/v1/registrations", params: {
          user: { email: "jane@example.com", password: "password123",
                  password_confirmation: "password123" }
        }
      }.to change(Users::User, :count).by(1)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["token"]).to be_present
      expect(body["user"]["email"]).to eq("jane@example.com")
    end

    it "rejects a mismatched password confirmation" do
      post "/api/v1/registrations", params: {
        user: { email: "jane@example.com", password: "password123",
                password_confirmation: "nope" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "rejects a duplicate email" do
      Users::User.create!(email: "jane@example.com", password: "password123",
                          password_confirmation: "password123")

      post "/api/v1/registrations", params: {
        user: { email: "jane@example.com", password: "password123",
                password_confirmation: "password123" }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
