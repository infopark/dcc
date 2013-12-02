# encoding: utf-8

def provide_bucket_group_config(default, extra = nil)
  File.stub(:read).with("git_path/dcc_config.rb").and_return <<-EOD
    #{default}

    buckets "default" do
      bucket(:one).performs_rake_tasks %w(1a 1b 1c)
      bucket(:two).performs_rake_tasks "2"
    end

    buckets "extra" do
      #{extra}
      bucket(:three).performs_rake_tasks('3a', '3b')
    end
  EOD
end

