# encoding: utf-8

def provide_bucket_group_config(default, extra = nil)
  allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return <<-EOD
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

def provide_project
  git = double("git",
    :current_commit => "current commit",
    :path => 'git_path',
    :remote_changed? => false
  )
  Project.new(:name => "name", :url => "url", :branch => "branch").tap do |p|
    allow(p).to receive(:git).and_return git
  end
end
