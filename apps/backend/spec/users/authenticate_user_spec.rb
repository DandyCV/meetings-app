require "rails_helper"

RSpec.describe Users::AuthenticateUser do
  let!(:user) do
    Users::User.create!(email: "jane@example.com", password: "password123",
                        password_confirmation: "password123")
  end

  it "returns the user for correct credentials" do
    expect(described_class.call(email: "jane@example.com", password: "password123")).to eq(user)
  end

  it "is case-insensitive on the email" do
    expect(described_class.call(email: "JANE@example.com", password: "password123")).to eq(user)
  end

  it "returns nil for a wrong password" do
    expect(described_class.call(email: "jane@example.com", password: "wrong")).to be_nil
  end

  it "returns nil for an unknown email" do
    expect(described_class.call(email: "nobody@example.com", password: "password123")).to be_nil
  end
end
