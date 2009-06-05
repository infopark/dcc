send_notifications_to "tilo@infopark.de"

buckets "test" do
  bucket(:specs).performs_rake_tasks("db:migrate", "spec")
end
