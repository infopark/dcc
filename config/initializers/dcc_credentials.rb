Infopark::Crm.configure do |config|
  config.url = 'https://infopark.crm.infopark.net/'
  config.login = 'webservice'
  config.api_key = ENV['CRM_API_KEY']
end
