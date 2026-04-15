class NotificationMailer < ApplicationMailer
  def notify
    @notification = params[:notification]
    mail(to: @notification.user.email, subject: "[SpendFlow] #{@notification.title}")
  end
end
