# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{dcc}
  s.version = "0.1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Tilo Pr\303\274tz"]
  s.date = %q{2009-05-30}
  s.default_executable = %q{worker}
  s.description = %q{Distributed Cruise Control for projects in git using rake.}
  s.email = %q{tilo@infopark.de}
  s.executables = ["worker"]
  s.extra_rdoc_files = [
    "README"
  ]
  s.files = [
    "app/controllers/application.rb",
     "app/controllers/project_controller.rb",
     "app/helpers/application_helper.rb",
     "app/helpers/project_helper.rb",
     "app/models/bucket.rb",
     "app/models/build.rb",
     "app/models/log.rb",
     "app/models/project.rb",
     "app/views/layouts/application.erb",
     "app/views/project/index.erb",
     "app/views/project/show.erb",
     "app/views/project/show_bucket.erb",
     "app/views/project/show_build.erb",
     "config/boot.rb",
     "config/database.yml",
     "config/environment.rb",
     "config/environments/development.rb",
     "config/environments/production.rb",
     "config/environments/test.rb",
     "config/initializers/inflections.rb",
     "config/initializers/mime_types.rb",
     "config/initializers/new_rails_defaults.rb",
     "config/locales/en.yml",
     "config/routes.rb",
     "db/development.sqlite3",
     "db/migrate/001_create_projects_buckets_and_logs.rb",
     "db/migrate/002_rename_commit_column.rb",
     "db/migrate/003_create_builds.rb",
     "db/migrate/004_add_worker_uri_to_buckets_and_update_status.rb",
     "db/schema.rb",
     "db/test.sqlite3",
     "lib/command_line.rb",
     "lib/cruise_control/log.rb",
     "lib/dcc_worker.rb",
     "lib/git.rb",
     "lib/mailer.rb",
     "lib/platform.rb",
     "lib/rake.rb",
     "lib/tasks/rspec.rake",
     "public/404.html",
     "public/422.html",
     "public/500.html",
     "public/dispatch.cgi",
     "public/dispatch.fcgi",
     "public/dispatch.rb",
     "public/favicon.ico",
     "public/images/diccr-favicon-big.ico",
     "public/images/diccr-favicon-medium.ico",
     "public/images/diccr-logo.png",
     "public/images/rails.png",
     "public/javascripts/application.js",
     "public/javascripts/controls.js",
     "public/javascripts/dragdrop.js",
     "public/javascripts/effects.js",
     "public/javascripts/jquery-ui.js",
     "public/javascripts/jquery.js",
     "public/javascripts/jrails.js",
     "public/javascripts/prototype.js",
     "public/robots.txt",
     "script/about",
     "script/autospec",
     "script/console",
     "script/dbconsole",
     "script/destroy",
     "script/generate",
     "script/performance/benchmarker",
     "script/performance/profiler",
     "script/performance/request",
     "script/plugin",
     "script/process/inspector",
     "script/process/reaper",
     "script/process/spawner",
     "script/runner",
     "script/server",
     "script/spec",
     "script/spec_server",
     "vendor/plugins/jrails/CHANGELOG",
     "vendor/plugins/jrails/README",
     "vendor/plugins/jrails/init.rb",
     "vendor/plugins/jrails/install.rb",
     "vendor/plugins/jrails/javascripts/jquery-ui.js",
     "vendor/plugins/jrails/javascripts/jquery.js",
     "vendor/plugins/jrails/javascripts/jrails.js",
     "vendor/plugins/jrails/javascripts/sources/jrails.js",
     "vendor/plugins/jrails/lib/jrails.rb",
     "vendor/plugins/jrails/tasks/jrails.rake"
  ]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/infopark/dcc}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{Distributed Cruise Control for projects in git using rake.}
  s.test_files = [
    "spec/helpers/project_helper_spec.rb",
     "spec/controllers/project_controller_spec.rb",
     "spec/controllers/build_controller_spec.rb",
     "spec/models/project_spec.rb",
     "spec/models/build_spec.rb",
     "spec/models/bucket_spec.rb",
     "spec/lib/dcc_worker_spec.rb",
     "spec/spec_helper.rb",
     "test/test_helper.rb",
     "test/performance/browsing_test.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<infopark-politics>, [">= 0.2.9"])
      s.add_runtime_dependency(%q<actionmailer>, [">= 2.2.2"])
      s.add_runtime_dependency(%q<rails>, [">= 2.2.2"])
      s.add_runtime_dependency(%q<rake>, [">= 0"])
    else
      s.add_dependency(%q<infopark-politics>, [">= 0.2.9"])
      s.add_dependency(%q<actionmailer>, [">= 2.2.2"])
      s.add_dependency(%q<rails>, [">= 2.2.2"])
      s.add_dependency(%q<rake>, [">= 0"])
    end
  else
    s.add_dependency(%q<infopark-politics>, [">= 0.2.9"])
    s.add_dependency(%q<actionmailer>, [">= 2.2.2"])
    s.add_dependency(%q<rails>, [">= 2.2.2"])
    s.add_dependency(%q<rake>, [">= 0"])
  end
end
