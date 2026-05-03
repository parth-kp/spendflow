module Approvals
  class Workflow
    class Error < StandardError; end

    def initialize(requisition, actor:)
      @requisition = requisition
      @actor = actor
    end

    def submit!
      requisition.with_lock do
        requisition.submit!
        requisition.approval_steps.destroy_all
        build_steps!
        audit(:submitted, total: requisition.total_amount.to_s("F"), levels: requisition.approval_steps.size)

        if requisition.approval_steps.empty?
          requisition.approve!
          audit(:auto_approved, reason: "no approval rule matched")
        end
        requisition.sync_current_step!
      end

      requisition.approved? ? notify_requester("approved") : notify_current_approvers
      requisition
    end

    def decide!(decision, comment: nil)
      raise Error, "Unknown decision #{decision}" unless %w[approve reject].include?(decision.to_s)

      requisition.with_lock do
        step = requisition.approval_steps.reload.detect(&:pending?)
        raise Error, "Nothing is waiting for approval" unless requisition.pending_approval? && step
        raise Error, "You cannot act on this approval step" unless step.actionable_by?(actor)
        raise Error, "A comment is required when rejecting" if decision.to_s == "reject" && comment.blank?

        decision.to_s == "approve" ? approve_step!(step, comment) : reject_step!(step, comment)
        requisition.sync_current_step!
      end

      after_decision_notifications
      requisition
    end

    private

    attr_reader :requisition, :actor

    def build_steps!
      ApprovalRule.chain_for(department: requisition.department, amount: requisition.total_amount).each do |rule|
        requisition.approval_steps.create!(
          company: requisition.company,
          approval_rule: rule,
          level: rule.level,
          approver_role: rule.approver_role,
          approver: rule.approver
        )
      end
      requisition.approval_steps.reset
    end

    def approve_step!(step, comment)
      record!(step, "approved", comment)
      audit(:step_approved, level: step.level, role: step.approver_role, comment: comment)

      return if requisition.approval_steps.any?(&:pending?)

      requisition.approve!
      audit(:approved)
    end

    def reject_step!(step, comment)
      record!(step, "rejected", comment)
      requisition.approval_steps.select(&:pending?).each { |s| s.update!(status: "skipped") }
      requisition.reject!
      audit(:rejected, level: step.level, role: step.approver_role, comment: comment)
    end

    def audit(action, **metadata)
      requisition.audit!(action, actor: actor, **metadata)
    end

    def record!(step, status, comment)
      step.update!(status: status, decided_by: actor, decided_at: Time.current, comment: comment)
    end

    def after_decision_notifications
      if requisition.approved? then notify_requester("approved")
      elsif requisition.rejected? then notify_requester("rejected")
      else notify_current_approvers
      end
    end

    def notify_current_approvers
      step = requisition.current_step
      return unless step

      ids = User.active.select { |u| step.actionable_by?(u) && !u.admin? }.map(&:id)
      ids = User.active.where(role: "admin").pluck(:id) if ids.empty?
      enqueue(ids, "approval_requested", "#{requisition.number} needs your approval",
              "#{requisition.requester.name} requested #{requisition.currency} #{requisition.total_amount.to_s('F')} for \"#{requisition.title}\" (level #{step.level}).")
    end

    def notify_requester(outcome)
      enqueue([requisition.requester_id], "requisition_#{outcome}", "#{requisition.number} was #{outcome}",
              "Your requisition \"#{requisition.title}\" was #{outcome}.")
    end

    def enqueue(user_ids, kind, title, body)
      return if user_ids.empty?

      NotifyUsersJob.perform_later(company_id: requisition.company_id, user_ids: user_ids, kind: kind,
                                   title: title, body: body, subject_gid: requisition.to_global_id.to_s)
    end
  end
end
