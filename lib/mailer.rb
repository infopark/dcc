require 'action_mailer'
#FIXME: Tests!
#FIXME: Mehr Infos über's Projekt per Parameter rein und in den Betreff

class Mailer < ActionMailer::Base
# FIXME
# -> Mail-Config per Projekt in dcc.conf
  def failure_message(bucket)
    from 'develop@infopark.de'
    recipients 'tilo@infopark.de'
    subject "#{bucket.project.name}-Build fehlgeschlagen"
    body %Q|
Projekt: #{bucket.project_name}
Build: #{bucket.commit}.#{bucket.build_number}
Task: #{bucket.name}

Log:

#{bucket.log}
|
  end
end
