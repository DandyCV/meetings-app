require "rails_helper"

RSpec.describe Users::RegisterUser do
  let(:valid_attrs) do
    { email: "jane@example.com", password: "password123", password_confirmation: "password123" }
  end

  it "creates a user and returns a success result wrapping it" do
    result = nil

    expect { result = described_class.call(**valid_attrs) }.to change(Users::User, :count).by(1)
    expect(result).to be_success
    expect(result.value).to be_a(Users::User)
    expect(result.value.email).to eq("jane@example.com")
  end

  it "fails with error messages on a mismatched confirmation" do
    result = described_class.call(**valid_attrs, password_confirmation: "nope")

    expect(result).to be_failure
    expect(result.errors).to be_present
    expect(result.value).to be_nil
  end

  it "fails on a duplicate email" do
    described_class.call(**valid_attrs)

    expect { described_class.call(**valid_attrs) }.not_to change(Users::User, :count)
  end
end
