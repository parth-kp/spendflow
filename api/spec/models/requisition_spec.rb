require "rails_helper"

RSpec.describe Requisition do
  it "assigns a sequential number per company" do
    company = create(:company)
    first = create(:requisition, company: company)
    second = create(:requisition, company: company)

    expect(first.number).to eq("REQ-00001")
    expect(second.number).to eq("REQ-00002")
  end

  it "computes totals from lines" do
    req = build(:requisition, company: create(:company))
    req.lines = [
      RequisitionLine.new(description: "Monitor", quantity: 2, unit_price: 199.99),
      RequisitionLine.new(description: "Cable", quantity: 3, unit_price: 5.5)
    ]
    req.save!

    expect(req.total_amount).to eq(BigDecimal("416.48"))
    expect(req.lines.map(&:line_total)).to eq([BigDecimal("399.98"), BigDecimal("16.5")])
  end

  it "inherits the requester department and company currency" do
    company = create(:company, currency: "EUR")
    dept = create(:department, company: company)
    user = create(:user, company: company, department: dept)
    req = Requisition.create!(company: company, requester: user, title: "Chairs",
                              lines_attributes: [{ description: "Chair", quantity: 1, unit_price: 100 }])

    expect(req.department).to eq(dept)
    expect(req.currency).to eq("EUR")
  end

  describe "state machine" do
    let(:req) { create(:requisition) }

    it "starts as draft" do
      expect(req).to be_draft
    end

    it "moves through submit and approve" do
      req.submit!
      expect(req).to be_pending_approval
      expect(req.submitted_at).to be_present

      req.approve!
      expect(req).to be_approved
    end

    it "does not allow approving a draft" do
      expect { req.approve! }.to raise_error(AASM::InvalidTransition)
    end

    it "can be revised after rejection" do
      req.submit!
      req.reject!
      req.revise!
      expect(req).to be_draft
      expect(req.submitted_at).to be_nil
    end

    it "refuses to submit without lines" do
      req.lines.each(&:mark_for_destruction)
      expect { req.submit! }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
