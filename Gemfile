source 'https://rubygems.org'

gem 'honeybadger'

gem 'daemon-spawn'
gem 'rails', '~>3.2.16'
gem 'mysql2'
gem 'json'
gem 'jquery-rails'
gem 'underscore-rails'
gem 'infopark-politics', '>= 0.5.0'
gem 'thin'
gem 'infopark_crm_connector'
gem 'http_accept_language'
# bootstrap from a gem
gem 'anjlab-bootstrap-rails', '~> 3.0.2.0', :require => 'bootstrap-rails'
# bootstrap-switch from a gem
# newer versions suffer from 'missing bootstrap-switch' on assets:precompile
gem "bootstrap-switch-rails", "1.8.1"
# bootbox from a gem
gem 'bootbox-rails', '~> 0.2'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'

  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  gem 'therubyracer', :platforms => :ruby

  gem 'uglifier', '>= 1.0.3'
end

group :development do
  gem 'rake'
  gem 'rspec-rails'
  gem 'pry'
end

group :test do
  gem 'sqlite3'
  gem 'cucumber-rails', require: false
  gem 'database_cleaner'
end
