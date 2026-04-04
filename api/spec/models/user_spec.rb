require "rails_helper"

RSpec.describe User do
  it { is_expected.to validate_inclusion_of(:role).in_array(User::ROLES) }

  it "normalizes email" do
    expect(create(:user, email: "  Jane@Example.COM ").email).to eq("jane@example.com")
  end

  it "keeps email unique across tenants so login is unambiguous" do
    create(:user, email: "x@example.com")
    expect(build(:user, email: "X@example.com", company: create(:company))).not_to be_valid
  end

  it "treats managers, finance and admins as approvers" do
    expect(build(:user).approver?).to be(false)
    expect(build(:user, :manager).approver?).to be(true)
    expect(build(:user, :finance).approver?).to be(true)
  end
end
