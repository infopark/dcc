require 'action_mailer'
#FIXME: Tests!
#FIXME: Mehr Infos über's Projekt per Parameter rein und in den Betreff

class Mailer < ActionMailer::Base
  def failure_message(bucket, host)
    message(bucket, host, 'fehlgeschlagen')
  end

  def fixed_message(bucket, host)
    message(bucket, host, 'repariert')
  end

private

  def message(bucket, host, state)
    build = bucket.build
    project = build.project
    from 'develop@infopark.de'
    recipients project.e_mail_receivers
    subject "[dcc][#{project.name}] '#{bucket.name}' #{state} auf #{host}"
    body %Q|
Projekt: #{project.name}
Build: #{build.identifier}
Task: #{bucket.name}

Log:

#{bucket.log}
|
  end
end
