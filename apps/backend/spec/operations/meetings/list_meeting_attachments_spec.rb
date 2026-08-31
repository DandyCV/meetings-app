require "rails_helper"

RSpec.describe Meetings::ListMeetingAttachments do
  let(:user) do
    Users::User.create!(email: "jane@example.com", password: "password123",
                        password_confirmation: "password123")
  end
  let(:meeting) { user.meetings.create!(title: "Standup", starts_at: 1.day.from_now) }
  let(:other_meeting) { user.meetings.create!(title: "Retro", starts_at: 2.days.from_now) }

  def attach(target, filename)
    a = target.meeting_attachments.build
    a.file.attach(io: StringIO.new("data"), filename: filename, content_type: "text/plain")
    a.save!
    a
  end

  it "returns only the given meeting's attachments, oldest first" do
    first = attach(meeting, "a.txt")
    second = attach(meeting, "b.txt")
    attach(other_meeting, "c.txt")

    expect(described_class.call(meeting: meeting).to_a).to eq([ first, second ])
  end

  it "returns an empty relation when the meeting has no attachments" do
    expect(described_class.call(meeting: meeting)).to be_empty
  end
end
