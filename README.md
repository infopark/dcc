# DCC - Distributed Cruise Control

The Distributed Cruise Control is a Infopark tool to continously test all aspects of the cloud
platform. It is reachable for Infopark employees under http://dcc.infopark.de/. Projects can be
created that get testet automatically if code is pushed to the specified branch.

## Installation and Usage

1. Visit http://dcc.infopark.de/ and log in with your Infopark credentials.

2. Create a new project and specify a `name`, `repository url` and a `branch`. Optionally you can
mark the project as `personal`, this way it is hidden for all other users by default, which helps to
organize and view projects more easily.

3. Create a `dcc_config.rb` file in your project and include at least one test bucket, that is run
when the code of the project changes. In `dcc_config.rb` you can specify what tests should be
executed.

   send_notifications_to 'me@infopark.de'

   before_all.performs_rake_tasks('test:setup')

   buckets 'test' do
     bucket(:specs).performs_rake_tasks('spec')
   end


## Contributing

1. Fork and clone the [DCC GitHub repository](https://github.com/infopark/dcc).

    git clone git@github.com:_username_/dcc.git
    cd dcc

2. Install MySQL, add `database.yml` and `config/initializers/my_crm_credentials.rb`. Please ask the
maintainer to obtain production credentials to connect your local development environment with the
production data. You need the `database host`, `database password`, `crm api key`, `crm url` and
`crm login`.

    brew install mysql
    cp config/database.yml.template config/database.yml
    touch config/intializers/my_crm_credentials.rb

    Infopark::Crm.configure do |config|
      config.url = <crm url>
      config.login = <crm login>
      config.api_key = <crm api key>
    end

3. Create the bundle and run all test to make sure everything is working before you add your own
changes.

    bundle
    rake spec

4. Create your feature branch and create a pull request for the `master` branch. Please take a look
at the already existing code to get an impression of our coding style and the general architecture.


## License

Copyright (c) 2009 - 2014 Infopark AG (http://www.infopark.com)
