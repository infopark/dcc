require 'action_mailer'
#FIXME: Tests!
#FIXME: Mehr Infos über's Projekt per Parameter rein und in den Betreff

class Mailer < ActionMailer::Base
  def failure_message(bucket, host)
    bucket_message(bucket, host, 'fehlgeschlagen')
  end

  def fixed_message(bucket, host)
    bucket_message(bucket, host, 'repariert')
  end

  def message(project, receivers, subject, message)
    from 'develop@infopark.de'
    recipients receivers
    subject "[dcc][#{project.name}] #{subject}"
    body %Q|
Projekt: #{project.name}
#{message}
|
  end

private

  def bucket_message(bucket, host, state)
    build = bucket.build
    message(build.project, build.project.e_mail_receivers, "'#{bucket.name}' #{state} auf #{host}",
"Build: #{build.identifier}
Task: #{bucket.name}

Log:

#{bucket.log}")
  end
end
