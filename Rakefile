# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "dcc"
    gemspec.summary = "Distributed Cruise Control for projects in git using rake."
    gemspec.email = "tilo@infopark.de"
    gemspec.homepage = "http://github.com/infopark/dcc"
    gemspec.description = gemspec.summary
    gemspec.authors = ["Tilo Prütz"]
    gemspec.add_dependency 'infopark-politics', '>=0.2.9'
    gemspec.add_dependency 'rails', '~>2.2'
    gemspec.add_dependency 'rake'
    gemspec.files = FileList["{app,config,db/migrate,lib,public,script,vendor}/**/*"]
  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end

require(File.join(File.dirname(__FILE__), 'config', 'boot'))

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

require 'tasks/rails'
