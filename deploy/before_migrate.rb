Chef::Log.info("=== Hook: before_migrate for #{release_path}")

shared_path = ::File.expand_path("#{release_path}/../../shared")
Chef::Log.info("= Shared path is #{shared_path}")

Chef::Log.info("= Creating initializers Dir #{shared_path}/config/initializers")
directory "#{shared_path}/config/initializers" do
  mode 0755
  action :create
  recursive true
  owner node[:opsworks][:deploy_user][:user]
  group node[:opsworks][:deploy_user][:group]
end

Chef::Log.info('= Building app config')

{
  :dcc_api_key => "Rails.configuration.dcc_api_key = '#{node[:deploy][:dcc][:api_key]}'",
  :dcc_credentials => nil,
  :crm_credentials => %Q@
    Infopark::Crm.configure do |config|
      config.url = '#{node[:deploy][:dcc][:webcrm][:url]}'
      config.login = '#{node[:deploy][:dcc][:webcrm][:login]}'
      config.api_key = '#{node[:deploy][:dcc][:webcrm][:api_key]}'
    end
  @,
  :honeybadger => %Q@
    Honeybadger.configure do |config|
      config.api_key = '#{node[:deploy][:dcc][:honeybadger][:api_key]}'
    end
  @
}.each do |config_name, config_content|
  config_path = "config/initializers/#{config_name}.rb"
  shared_config_path = ::File.join(shared_path, config_path)
  released_config_path = ::File.join(release_path, config_path)

  Chef::Log.info("= Deleting old shared app config #{shared_config_path}")
  file shared_config_path do
    action :delete
  end

  Chef::Log.info("= Deleting default app config #{released_config_path}")
  file released_config_path do
    action :delete
  end

  if config_content
    Chef::Log.info("= Writing config file to #{shared_config_path}")
    file shared_config_path do
      owner node[:opsworks][:deploy_user][:user]
      group node[:opsworks][:deploy_user][:group]
      action :create
      content config_content
    end

    Chef::Log.info("= Link app config #{released_config_path} to #{shared_config_path}")
    link released_config_path do
      to shared_config_path
      owner node[:opsworks][:deploy_user][:user]
    end
  end
end
