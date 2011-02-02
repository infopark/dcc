require 'action_mailer'
#FIXME: Tests!
#FIXME: Mehr Infos über's Projekt per Parameter rein und in den Betreff

class Mailer < ActionMailer::Base
  def failure_message(bucket, host)
    bucket_state_message(bucket, host, 'fehlgeschlagen')
  end

  def fixed_message(bucket, host)
    bucket_state_message(bucket, host, 'repariert')
  end

  def message(receivers, subject, message)
    from 'develop@infopark.de'
    recipients receivers
    subject "[dcc]#{" " unless subject =~ /^\[/}#{subject}"
    body "\n#{message}\n-- \nSent to you by diccr - the distributed cruise control app.\n"
  end

private

  def project_message(project, receivers, subject, message)
    message(receivers, "[#{project.name}] #{subject}", "Projekt: #{project.name}\n#{message}")
  end

  def bucket_message(bucket, receivers, subject, message)
    build = bucket.build
    project_message(build.project, receivers, subject,
        "Build: #{build.identifier}\nTask: #{bucket.name}\n#{message}")
  end

  def bucket_state_message(bucket, host, state)
    bucket_message(bucket, bucket.build.project.e_mail_receivers(bucket.name),
        "'#{bucket.name}' #{state} auf #{host}",
        "#{
          "\nFehler:\n\n#{bucket.error_log}\n\n#{'-' * 75}" if bucket.error_log
        }\nLog:\n\n#{bucket.log}")
  end
end
