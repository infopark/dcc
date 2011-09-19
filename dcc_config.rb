
send_notifications_to "tilo@infopark.de"

before_all.performs_rake_tasks("db:migrate")

buckets "test" do
  bucket(:specs).performs_rake_tasks("spec")
  bucket(:features).performs_rake_tasks("cucumber")
end
