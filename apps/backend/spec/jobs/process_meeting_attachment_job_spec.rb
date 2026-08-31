require "rails_helper"

RSpec.describe ProcessMeetingAttachmentJob, type: :job do
  let(:user) do
    Users::User.create!(email: "jane@example.com", password: "password123",
                        password_confirmation: "password123")
  end
  let(:meeting) { user.meetings.create!(title: "Standup", starts_at: 1.day.from_now) }

  def create_attachment
    attachment = meeting.meeting_attachments.build
    attachment.file.attach(io: StringIO.new("hello"), filename: "notes.txt",
                           content_type: "text/plain")
    attachment.save!
    attachment
  end

  it "moves the attachment from pending to processed and stamps processed_at" do
    attachment = create_attachment

    expect { described_class.perform_now(attachment) }
      .to change { attachment.reload.processing_status }.from("pending").to("processed")

    expect(attachment.processed_at).to be_present
  end
end
