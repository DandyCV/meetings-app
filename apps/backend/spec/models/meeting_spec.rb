require "rails_helper"

RSpec.describe Meeting, type: :model do
  let(:user) do
    User.create!(email: "jane@example.com", password: "password123",
                 password_confirmation: "password123")
  end

  def build_meeting(**attrs)
    user.meetings.build({ title: "Standup", starts_at: 1.day.from_now }.merge(attrs))
  end

  it "is valid with a title, a start time, and a user" do
    expect(build_meeting).to be_valid
  end

  it "requires a title" do
    meeting = build_meeting(title: nil)

    expect(meeting).not_to be_valid
    expect(meeting.errors[:title]).to be_present
  end

  it "requires a start time" do
    meeting = build_meeting(starts_at: nil)

    expect(meeting).not_to be_valid
    expect(meeting.errors[:starts_at]).to be_present
  end

  it "requires a user" do
    meeting = Meeting.new(title: "Standup", starts_at: 1.day.from_now)

    expect(meeting).not_to be_valid
    expect(meeting.errors[:user]).to be_present
  end

  describe ".recent_first" do
    it "orders meetings by starts_at descending" do
      earlier = build_meeting(title: "Earlier", starts_at: 2.days.from_now).tap(&:save!)
      later = build_meeting(title: "Later", starts_at: 5.days.from_now).tap(&:save!)

      expect(user.meetings.recent_first).to eq([ later, earlier ])
    end
  end
end
