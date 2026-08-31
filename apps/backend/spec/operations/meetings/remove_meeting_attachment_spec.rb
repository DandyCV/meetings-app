require "rails_helper"

RSpec.describe Meetings::RemoveMeetingAttachment do
  let(:user) do
    Users::User.create!(email: "jane@example.com", password: "password123",
                        password_confirmation: "password123")
  end
  let(:meeting) { user.meetings.create!(title: "Standup", starts_at: 1.day.from_now) }
  let(:other_meeting) { user.meetings.create!(title: "Retro", starts_at: 2.days.from_now) }

  def attach(target)
    a = target.meeting_attachments.build
    a.file.attach(io: StringIO.new("data"), filename: "a.txt", content_type: "text/plain")
    a.save!
    a
  end

  it "destroys an attachment that belongs to the meeting" do
    attachment = attach(meeting)

    expect { described_class.call(meeting: meeting, id: attachment.id) }
      .to change { meeting.meeting_attachments.count }.by(-1)
  end

  it "returns success wrapping the destroyed attachment" do
    attachment = attach(meeting)
    result = described_class.call(meeting: meeting, id: attachment.id)

    expect(result).to be_success
    expect(result.value.id).to eq(attachment.id)
  end

  it "purges the blob synchronously rather than deferring it" do
    attachment = attach(meeting)

    expect { described_class.call(meeting: meeting, id: attachment.id) }
      .to change(ActiveStorage::Blob, :count).by(-1)
  end

  it "fails when the id is not an attachment on this meeting" do
    foreign = attach(other_meeting)
    result = described_class.call(meeting: meeting, id: foreign.id)

    expect(result).to be_failure
    expect(MeetingAttachment.exists?(foreign.id)).to be(true)
  end
end
