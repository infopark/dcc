Crm.configure do |config|
  config.tenant = 'infopark'
  config.login = 'webservice'
  config.api_key = ENV['CRM_API_KEY']
end
