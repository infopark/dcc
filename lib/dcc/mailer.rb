# encoding: utf-8
require 'action_mailer'
#FIXME: Tests!
#FIXME: Mehr Infos über's Projekt per Parameter rein und in den Betreff

module DCC

class Mailer < ActionMailer::Base
  def failure_message(bucket)
    bucket_state_message(bucket, 'fehlgeschlagen')
  end

  def fixed_message(bucket)
    bucket_state_message(bucket, 'repariert')
  end

  def dcc_message(receivers, subject, message)
    mail to: (receivers.blank? ? self.class.default[:to] : receivers),
        subject: "[dcc]#{" " unless subject =~ /^\[/}#{subject}",
        content_type: 'text/plain',
        body: "#{message}\n-- \nSent to you by diccr - the distributed cruise control app.\n"
  end

private

  def project_message(project, receivers, subject, message)
    dcc_message(receivers, "[#{project.name}] #{subject}", "Projekt: #{project.name}\n#{message}")
  end

  def bucket_message(bucket, receivers, subject, message)
    build = bucket.build
    project_message(build.project, receivers, subject,
        "Build: #{build.identifier}\nTask: #{bucket.name}\n#{message}")
  end

  def bucket_state_message(bucket, state)
    bucket_message(bucket, bucket.build.project.e_mail_receivers(bucket.name),
        "'#{bucket.name}' #{state} auf #{Socket.gethostname}",
        "")
        # TODO das ist zuviel für Google-SES (führt zu Broken Pipe)
        #"#{
        #  "\nFehler:\n\n#{bucket.error_log}\n\n#{'-' * 75}" if bucket.error_log
        #}\nLog:\n\n#{bucket.log}")
  end
end

end
