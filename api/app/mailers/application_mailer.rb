class ApplicationMailer < ActionMailer::Base
  default from: "notifications@spendflow.app"
  layout "mailer"
end
