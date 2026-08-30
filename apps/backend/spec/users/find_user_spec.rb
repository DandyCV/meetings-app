require "rails_helper"

RSpec.describe Users::FindUser do
  it "returns the user with the given id" do
    user = Users::User.create!(email: "jane@example.com", password: "password123",
                               password_confirmation: "password123")

    expect(described_class.call(id: user.id)).to eq(user)
  end

  it "returns nil when there is no such user" do
    expect(described_class.call(id: 0)).to be_nil
  end
end
