require "rails_helper"

RSpec.describe Meetings::AttachMeetingFile do
  include ActiveJob::TestHelper

  let(:user) do
    Users::User.create!(email: "jane@example.com", password: "password123",
                        password_confirmation: "password123")
  end
  let(:meeting) { user.meetings.create!(title: "Standup", starts_at: 1.day.from_now) }

  def uploaded_file(name: "sample.txt", type: "text/plain", content: "hello world")
    file = Tempfile.new(name)
    file.write(content)
    file.rewind
    ActionDispatch::Http::UploadedFile.new(
      tempfile: file, filename: name, type: type
    )
  end

  it "persists an attachment on the meeting and returns it in a success result" do
    result = nil

    expect { result = described_class.call(meeting: meeting, file: uploaded_file) }
      .to change { meeting.meeting_attachments.count }.by(1)

    expect(result).to be_success
    expect(result.value).to be_a(MeetingAttachment)
    expect(result.value.file.filename.to_s).to eq("sample.txt")
    expect(result.value.processing_status).to eq("pending")
  end

  it "enqueues exactly one processing job for the new attachment" do
    expect { described_class.call(meeting: meeting, file: uploaded_file) }
      .to have_enqueued_job(ProcessMeetingAttachmentJob).exactly(:once)
  end

  it "fails when no file is given" do
    result = described_class.call(meeting: meeting, file: nil)

    expect(result).to be_failure
    expect(result.errors).to be_present
    expect(meeting.meeting_attachments.count).to eq(0)
  end

  it "fails on an empty file and enqueues nothing" do
    expect do
      result = described_class.call(meeting: meeting, file: uploaded_file(content: ""))
      expect(result).to be_failure
    end.not_to have_enqueued_job(ProcessMeetingAttachmentJob)
  end

  it "fails on a file above the size limit" do
    big = uploaded_file(content: "x" * (MeetingAttachment::MAX_FILE_SIZE + 1))
    result = described_class.call(meeting: meeting, file: big)

    expect(result).to be_failure
    expect(result.errors.join).to match(/limit/i)
  end

  it "fails on a disallowed content type" do
    result = described_class.call(
      meeting: meeting, file: uploaded_file(name: "a.exe", type: "application/x-msdownload")
    )

    expect(result).to be_failure
    expect(result.errors.join).to match(/not allowed/i)
  end
end
