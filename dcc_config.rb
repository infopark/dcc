# encoding: utf-8
require 'yaml'

send_notifications_to "tilo@infopark.de"

before_all do
  File.open("config/database.yml", "w") do |f|
    f.puts({
      'development' => {
        'adapter' => 'sqlite3',
        'database' => 'db/development.sqlite3',
        'pool' => 5,
        'timeout' => 5000
      },
      'test' => {
        'adapter' => 'sqlite3',
        'database' => 'db/test.sqlite3',
        'pool' => 5,
        'timeout' => 5000
      },
      'cucumber' => {
        'adapter' => 'sqlite3',
        'database' => 'db/test.sqlite3',
        'pool' => 5,
        'timeout' => 5000
      }
    }.to_yaml)
  end
end

before_all.performs_rake_tasks("db:migrate")

buckets "test" do
  bucket(:specs).performs_rake_tasks("spec")
  bucket(:features).performs_rake_tasks("cucumber:full_ok")
end
