require 'politics'
require 'politics/static_queue_worker'
require 'app/models/project'
require 'app/models/bucket'
require 'app/models/log'
require 'lib/rake'
require 'lib/mailer'

class DCCWorker
  include Politics::StaticQueueWorker

  def initialize(group_name, memcached_servers, options = {})
    options = {:log_level => Logger::WARN, :servers => memcached_servers, :iteration_length => 10
        }.merge(options)
    log.level = options[:log_level]
    log.formatter = Logger::Formatter.new()
    register_worker group_name, 0, options
  end

  def run
    log.debug "running"
    process_bucket do |bucket_id|
      perform_task Bucket.find(bucket_id)
    end
  end

  def perform_task(bucket)
    log.debug "performing task #{bucket}"
    logs = bucket.logs
    project = bucket.project
    git = project.git
    git.update
    succeeded = true
    project.tasks[bucket.name].each do |task|
      succeeded = perform_rake_task(git.path, task, logs) && succeeded
    end
    whole_log = ''
    logs.each do |log|
      whole_log << log.log
    end
    bucket.log = whole_log
    bucket.status = succeeded ? 1 : 2
    bucket.save
# FIXME
# Tests! fürs Mail-Zeux
    if !succeeded
      Mailer.deliver_failure_message(bucket, @url)
    elsif last_bucket = Bucket.find(:conditions => "bucket_id < #{bucket.bucket_id}", :limit => 1,
        :order => 'DESC') && last_bucket.status != 1
      Mailer.deliver_fixed_message(bucket, @url)
    end
    logs.clear
  end

  def perform_rake_task(path, task, logs)
    rake = Rake.new(path)
    old_connections = ActiveRecord::Base.connection_pool
    old_connections.disconnect!
    pid = fork do
      ActiveRecord::Base.establish_connection(old_connections.spec.config)
      begin
        rake.rake(task)
      rescue
        exit 1
      end
      exit 0
    end
    ActiveRecord::Base.establish_connection(old_connections.spec.config)
    log_length = 0
    while !Process.waitpid(pid, Process::WNOHANG)
      log_length += read_log_into_db(rake.log_file, log_length, logs)
      sleep log_polling_intervall
    end
    read_log_into_db(rake.log_file, log_length, logs)
    $?.exitstatus == 0
  end

  def read_log_into_db(log_file, log_length, logs)
    log = File.exists?(log_file) ? File.open(log_file) do |f|
      f.seek log_length
      f.read
    end : nil
    if log && !log.empty?
      logs.create(:log => log)
      log.length
    else
      0
    end
  end

  def log_polling_intervall
    return 10
  end

  def initialize_buckets
    log.debug "initializing buckets"
    @buckets = read_buckets
  end

  def read_buckets
    buckets = []
    log.debug "reading buckets"
    Project.find(:all).each do |project|
      log.debug "reading buckets for project #{project}"
      if project.build_requested? || project.current_commit != project.last_commit
        build_number = project.next_build_number
        log.debug "set up buckets for project #{project} with build_number #{build_number}" +
            " because #{project.build_requested?} ||" +
            " #{project.current_commit} != #{project.last_commit}"
        project.tasks.each_key do |task|
          bucket = project.buckets.create(:commit => project.current_commit,
              :build_number => build_number, :name => task, :status => 0)
          buckets << bucket.id
        end
        update_project project
      end
    end
    log.debug "read buckets #{buckets.inspect}"
    buckets
  end

  def update_project(project)
    log.debug "updating project #{project} with commit #{project.current_commit}"
    project.last_commit = project.current_commit
    project.build_requested = false
    project.save
    log.debug "project's last commit is now #{project.last_commit}"
  end
end
