require "rails_helper"

RSpec.describe MeetingAttachment, type: :model do
  let(:user) do
    Users::User.create!(email: "jane@example.com", password: "password123",
                        password_confirmation: "password123")
  end
  let(:meeting) { user.meetings.create!(title: "Standup", starts_at: 1.day.from_now) }

  def build_attachment(filename: "notes.txt", content_type: "text/plain", content: "hello")
    attachment = meeting.meeting_attachments.build
    attachment.file.attach(
      io: StringIO.new(content), filename: filename, content_type: content_type
    )
    attachment
  end

  it "is valid with a meeting and an allowed, non-empty, within-limit file" do
    expect(build_attachment).to be_valid
  end

  it "defaults processing_status to pending" do
    expect(MeetingAttachment.new.processing_status).to eq("pending")
  end

  it "requires a meeting" do
    attachment = MeetingAttachment.new
    attachment.valid?
    expect(attachment.errors[:meeting]).to be_present
  end

  it "requires a file to be attached" do
    attachment = meeting.meeting_attachments.build
    expect(attachment).not_to be_valid
    expect(attachment.errors[:file]).to be_present
  end

  it "rejects an empty file" do
    attachment = build_attachment(content: "")
    expect(attachment).not_to be_valid
    expect(attachment.errors[:file]).to be_present
  end

  it "rejects a file above the size limit" do
    attachment = build_attachment(content: "x" * (MeetingAttachment::MAX_FILE_SIZE + 1))
    expect(attachment).not_to be_valid
    expect(attachment.errors[:file]).to be_present
  end

  it "rejects a disallowed content type" do
    attachment = build_attachment(filename: "a.exe", content_type: "application/x-msdownload")
    expect(attachment).not_to be_valid
    expect(attachment.errors[:file]).to be_present
  end
end
