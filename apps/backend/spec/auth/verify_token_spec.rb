require "rails_helper"

RSpec.describe Auth::VerifyToken do
  it "returns the user id carried by a valid token" do
    token = Auth::GenerateToken.call(user_id: 7)

    expect(described_class.call(token: token)).to eq(7)
  end

  it "returns nil for a blank token" do
    expect(described_class.call(token: nil)).to be_nil
    expect(described_class.call(token: "")).to be_nil
  end

  it "returns nil for a malformed or tampered token" do
    expect(described_class.call(token: "not-a-real-token")).to be_nil
  end
end
