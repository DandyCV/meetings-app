require "rails_helper"

RSpec.describe "Api::V1::Meeting attachments", type: :request do
  include ActiveJob::TestHelper

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
  let(:meeting) { user.meetings.create!(title: "Standup", starts_at: 1.day.from_now) }

  def upload(name: "sample.txt", type: "text/plain", content: "hello world")
    Rack::Test::UploadedFile.new(StringIO.new(content), type, original_filename: name)
  end

  def create_attachment(target: meeting, filename: "existing.txt")
    a = target.meeting_attachments.build
    a.file.attach(io: StringIO.new("data"), filename: filename, content_type: "text/plain")
    a.save!
    a
  end

  describe "GET /api/v1/meetings/:meeting_id/attachments" do
    it "returns the meeting's attachments for the owner" do
      created = create_attachment(filename: "agenda.txt")

      get "/api/v1/meetings/#{meeting.id}/attachments", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.length).to eq(1)
      expect(response.parsed_body.first).to include(
        "id" => created.id,
        "meeting_id" => meeting.id,
        "filename" => "agenda.txt",
        "content_type" => "text/plain",
        "processing_status" => "pending",
        "processed_at" => nil,
        "download_url" => "/api/v1/meetings/#{meeting.id}/attachments/#{created.id}/download"
      )
      expect(response.parsed_body.first["byte_size"]).to be_positive
      expect(response.parsed_body.first["created_at"]).to be_present
    end

    it "returns an empty array when there are none" do
      get "/api/v1/meetings/#{meeting.id}/attachments", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "returns 404 for another user's meeting" do
      foreign = other_user.meetings.create!(title: "Not mine", starts_at: 1.day.from_now)

      get "/api/v1/meetings/#{foreign.id}/attachments", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when the meeting does not exist" do
      get "/api/v1/meetings/999999/attachments", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "rejects unauthenticated requests" do
      get "/api/v1/meetings/#{meeting.id}/attachments"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/meetings/:meeting_id/attachments" do
    it "creates an attachment and returns it with a pending status" do
      expect do
        post "/api/v1/meetings/#{meeting.id}/attachments",
             params: { attachment: { file: upload(name: "deck.txt") } },
             headers: auth_headers
      end.to change { meeting.meeting_attachments.count }.by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include(
        "filename" => "deck.txt",
        "processing_status" => "pending"
      )
      expect(response.parsed_body["id"]).to be_present
    end

    it "enqueues exactly one processing job" do
      expect do
        post "/api/v1/meetings/#{meeting.id}/attachments",
             params: { attachment: { file: upload } }, headers: auth_headers
      end.to have_enqueued_job(ProcessMeetingAttachmentJob).exactly(:once)
    end

    it "keeps both files when two uploads share a filename" do
      2.times do
        post "/api/v1/meetings/#{meeting.id}/attachments",
             params: { attachment: { file: upload(name: "notes.txt") } },
             headers: auth_headers
      end

      get "/api/v1/meetings/#{meeting.id}/attachments", headers: auth_headers
      expect(response.parsed_body.map { |a| a["filename"] }).to eq([ "notes.txt", "notes.txt" ])
    end

    it "returns 422 when no file is given" do
      post "/api/v1/meetings/#{meeting.id}/attachments",
           params: { attachment: {} }, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "returns 422 for an empty file" do
      post "/api/v1/meetings/#{meeting.id}/attachments",
           params: { attachment: { file: upload(content: "") } }, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 422 for a disallowed content type" do
      post "/api/v1/meetings/#{meeting.id}/attachments",
           params: { attachment: { file: upload(name: "a.exe", type: "application/x-msdownload") } },
           headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 422 for a file over the size limit" do
      post "/api/v1/meetings/#{meeting.id}/attachments",
           params: { attachment: { file: upload(content: "x" * (MeetingAttachment::MAX_FILE_SIZE + 1)) } },
           headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 404 for another user's meeting" do
      foreign = other_user.meetings.create!(title: "Not mine", starts_at: 1.day.from_now)

      post "/api/v1/meetings/#{foreign.id}/attachments",
           params: { attachment: { file: upload } }, headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "rejects unauthenticated requests" do
      post "/api/v1/meetings/#{meeting.id}/attachments",
           params: { attachment: { file: upload } }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
