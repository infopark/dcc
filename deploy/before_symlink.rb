Chef::Log.info('=== Hook: before_symlink')

Chef::Log.info('= Precompile assets')
execute 'rake assets:precompile' do
  cwd release_path
  command 'bundle exec rake assets:precompile'
  environment 'RAILS_ENV' => node[:deploy][:employeeapps][:rails_env]
end

Chef::Log.info('= Write revision.txt')
run("cd #{release_path} && (git describe --always --abbrev=16 >public/revision.txt)")
