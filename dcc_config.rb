# encoding: utf-8
require 'yaml'

send_notifications_to 'tilo@infopark.de'

before_all.performs_rake_tasks('test:setup')

buckets 'test' do
  bucket(:specs).performs_rake_tasks('spec')
end
