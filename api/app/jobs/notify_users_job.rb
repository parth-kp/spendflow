class NotifyUsersJob < ApplicationJob
  queue_as :default

  def perform(company_id:, user_ids:, kind:, title:, body: nil, subject_gid: nil)
    with_company(company_id) do
      subject = subject_gid && GlobalID::Locator.locate(subject_gid)

      User.active.where(id: user_ids).find_each do |user|
        notification = Notification.create!(user: user, kind: kind, title: title, body: body, subject: subject)
        NotificationMailer.with(notification: notification).notify.deliver_now
      end
    end
  end
end
