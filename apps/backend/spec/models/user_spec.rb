require "rails_helper"

RSpec.describe User, type: :model do
  def build_user(**attrs)
    User.new({ email: "jane@example.com", password: "password123",
               password_confirmation: "password123" }.merge(attrs))
  end

  it "is valid with a unique email and a matching password confirmation" do
    expect(build_user).to be_valid
  end

  it "requires an email" do
    user = build_user(email: nil)

    expect(user).not_to be_valid
    expect(user.errors[:email]).to be_present
  end

  it "requires a properly formatted email" do
    user = build_user(email: "not-an-email")

    expect(user).not_to be_valid
    expect(user.errors[:email]).to be_present
  end

  it "rejects a duplicate email, case-insensitively" do
    build_user.save!
    duplicate = build_user(email: "JANE@example.com")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email]).to be_present
  end

  it "normalizes email to a stripped, downcased value" do
    user = build_user(email: "  Jane@Example.com  ")
    user.save!

    expect(user.email).to eq("jane@example.com")
  end

  it "requires a password of at least 8 characters" do
    user = build_user(password: "short", password_confirmation: "short")

    expect(user).not_to be_valid
    expect(user.errors[:password]).to be_present
  end

  it "authenticates with the correct password" do
    user = build_user(password: "password123", password_confirmation: "password123")
    user.save!

    expect(user.authenticate("password123")).to eq(user)
    expect(user.authenticate("wrong")).to be false
  end

  it "destroys its meetings when destroyed" do
    user = build_user
    user.save!
    user.meetings.create!(title: "Standup", starts_at: 1.day.from_now)

    expect { user.destroy }.to change(Meeting, :count).by(-1)
  end
end
