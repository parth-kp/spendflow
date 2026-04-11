require "rails_helper"

RSpec.describe AuditEvent do
  let(:supplier) { create(:supplier) }

  def event
    described_class.create!(company: supplier.company, auditable: supplier, action: "created")
  end

  it "captures the current user as actor" do
    user = create(:user, company: supplier.company)
    Current.set(user: user) { expect(event.actor).to eq(user) }
  end

  it "cannot be modified once written" do
    e = event
    expect { e.update!(action: "tampered") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "cannot be destroyed" do
    e = event
    expect { e.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end
end
