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

    it "normalizes the email (strip + downcase) before persisting" do
      post "/api/v1/registrations", params: {
        user: { email: "  JANE@Example.COM  ", password: "password123",
                password_confirmation: "password123" }
      }

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["user"]["email"]).to eq("jane@example.com")
      expect(Users::User.last.email).to eq("jane@example.com")
    end

    it "rejects a blank email" do
      post "/api/v1/registrations", params: {
        user: { email: "", password: "password123", password_confirmation: "password123" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "rejects an email with an invalid format" do
      post "/api/v1/registrations", params: {
        user: { email: "not-an-email", password: "password123",
                password_confirmation: "password123" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "rejects a password shorter than 8 characters" do
      post "/api/v1/registrations", params: {
        user: { email: "jane@example.com", password: "short", password_confirmation: "short" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "rejects a missing password" do
      post "/api/v1/registrations", params: {
        user: { email: "jane@example.com" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "rejects a request with no user param" do
      post "/api/v1/registrations", params: {}

      expect(response).to have_http_status(:bad_request)
    end

    it "does not create a user when validation fails" do
      expect {
        post "/api/v1/registrations", params: {
          user: { email: "not-an-email", password: "password123",
                  password_confirmation: "password123" }
        }
      }.not_to change(Users::User, :count)
    end
  end
end
