Chef::Log.info('=== Hook: after_restart')

Chef::Log.info('= Notify honeybadger about deploy')
revision = %x(git rev-parse HEAD).strip
run "bundle exec rake environment honeybadger:deploy_with_environment TO=production REVISION=#{revision} REPO=https://github.com/infopark/dcc"
