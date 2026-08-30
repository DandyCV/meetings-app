require "rails_helper"

RSpec.describe "Api::V1::Meetings", type: :request do
  let(:user) do
    Users::User.create!(email: "jane@example.com", password: "password123",
                        password_confirmation: "password123")
  end
  let(:other_user) do
    Users::User.create!(email: "john@example.com", password: "password123",
                        password_confirmation: "password123")
  end
  let(:token) { Auth::GenerateToken.call(user_id: user.id) }
  let(:auth_headers) { { "Authorization" => "Bearer #{token}" } }

  describe "GET /api/v1/meetings" do
    it "returns only the current user's meetings, most recent first" do
      earlier = user.meetings.create!(title: "Standup", starts_at: 1.day.from_now)
      later = user.meetings.create!(title: "Retro", starts_at: 3.days.from_now)
      other_user.meetings.create!(title: "Not mine", starts_at: 2.days.from_now)

      get "/api/v1/meetings", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck("id")).to eq([ later.id, earlier.id ])
    end

    it "returns an empty array when the user has no meetings" do
      get "/api/v1/meetings", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "rejects unauthenticated requests" do
      get "/api/v1/meetings"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
