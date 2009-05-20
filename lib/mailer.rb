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
    from 'develop@infopark.de'
    recipients bucket.project.e_mail_receivers
    subject "#{bucket.project.name}-Build #{state} auf #{host}"
    body %Q|
Projekt: #{bucket.project.name}
Build: #{bucket.commit}.#{bucket.build_number}
Task: #{bucket.name}

Log:

#{bucket.log}
|
  end
end
