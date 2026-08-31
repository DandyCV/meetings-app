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

    it "returns an accurate attachments_count for each row" do
      meeting = user.meetings.create!(title: "Standup", starts_at: 1.day.from_now)
      3.times do |i|
        a = meeting.meeting_attachments.build
        a.file.attach(io: StringIO.new("x"), filename: "f#{i}.txt", content_type: "text/plain")
        a.save!
      end

      get "/api/v1/meetings", headers: auth_headers

      row = response.parsed_body.find { |m| m["id"] == meeting.id }
      expect(row["attachments_count"]).to eq(3)
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

  describe "GET /api/v1/meetings/:id" do
    it "returns the meeting when it belongs to the current user" do
      meeting = user.meetings.create!(title: "Planning", description: "Q3 goals",
                                      starts_at: 2.days.from_now)

      get "/api/v1/meetings/#{meeting.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "id" => meeting.id,
        "title" => "Planning",
        "description" => "Q3 goals"
      )
    end

    it "includes an accurate attachments_count" do
      meeting = user.meetings.create!(title: "Planning", starts_at: 2.days.from_now)
      2.times do |i|
        a = meeting.meeting_attachments.build
        a.file.attach(io: StringIO.new("x"), filename: "f#{i}.txt", content_type: "text/plain")
        a.save!
      end

      get "/api/v1/meetings/#{meeting.id}", headers: auth_headers

      expect(response.parsed_body["attachments_count"]).to eq(2)
    end

    it "returns 404 for a meeting that belongs to another user" do
      meeting = other_user.meetings.create!(title: "Not mine", starts_at: 1.day.from_now)

      get "/api/v1/meetings/#{meeting.id}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when the meeting does not exist" do
      get "/api/v1/meetings/999999", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "rejects unauthenticated requests" do
      meeting = user.meetings.create!(title: "Planning", starts_at: 1.day.from_now)

      get "/api/v1/meetings/#{meeting.id}"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/meetings" do
    let(:valid_params) do
      { meeting: { title: "Kickoff", description: "Project kickoff",
                   starts_at: 3.days.from_now.iso8601 } }
    end

    it "creates a meeting for the current user" do
      expect do
        post "/api/v1/meetings", params: valid_params, headers: auth_headers
      end.to change(user.meetings, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include(
        "title" => "Kickoff",
        "description" => "Project kickoff"
      )
      expect(response.parsed_body["id"]).to be_present
    end

    it "returns 422 with errors when the title is missing" do
      post "/api/v1/meetings",
           params: { meeting: { starts_at: 1.day.from_now.iso8601 } },
           headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "rejects unauthenticated requests" do
      expect do
        post "/api/v1/meetings", params: valid_params
      end.not_to change(Meeting, :count)

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
