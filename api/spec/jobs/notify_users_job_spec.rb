require "rails_helper"

RSpec.describe NotifyUsersJob do
  let(:company) { create(:company) }
  let!(:alice) { create(:user, company: company) }
  let!(:inactive) { create(:user, company: company, active: false) }

  it "creates in-app notifications and emails active users" do
    expect {
      described_class.perform_now(company_id: company.id, user_ids: [alice.id, inactive.id],
                                  kind: "approval_requested", title: "Please review REQ-00001")
    }.to change(Notification, :count).by(1).and change(ActionMailer::Base.deliveries, :size).by(1)

    expect(ActionMailer::Base.deliveries.last.to).to eq([alice.email])
  end

  it "runs inside the job's tenant" do
    described_class.perform_now(company_id: company.id, user_ids: [alice.id], kind: "x", title: "t")
    expect(Notification.last.company).to eq(company)
  end
end
