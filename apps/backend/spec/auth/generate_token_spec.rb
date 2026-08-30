require "rails_helper"

RSpec.describe Auth::GenerateToken do
  it "mints a token that VerifyToken can resolve back to the user id" do
    token = described_class.call(user_id: 42)

    expect(token).to be_a(String)
    expect(Auth::VerifyToken.call(token: token)).to eq(42)
  end

  it "honours an explicit expiry" do
    token = described_class.call(user_id: 42, expires_at: 1.hour.ago)

    expect(Auth::VerifyToken.call(token: token)).to be_nil
  end
end
