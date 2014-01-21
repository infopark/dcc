file 'config/database.yml' do
  File.open('config/database.yml', 'w') do |f|
    f.puts({
      'development' => {
        'adapter' => 'sqlite3',
        'database' => 'db/development.sqlite3',
        'pool' => 5,
        'timeout' => 5000
      },
      'test' => {
        'adapter' => 'sqlite3',
        'database' => 'db/test.sqlite3',
        'pool' => 5,
        'timeout' => 5000
      },
    }.to_yaml)
  end
end

namespace :test do
  task :setup => ['config/database.yml', 'db:migrate']
end
