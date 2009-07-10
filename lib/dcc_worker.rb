require 'politics'
require 'politics/static_queue_worker'
require 'app/models/project'
require 'app/models/build'
require 'app/models/bucket'
require 'app/models/log'
require 'lib/rake'
require 'lib/mailer'
require 'lib/bucket_store'
require 'monitor'

class DCCWorker
  include Politics::StaticQueueWorker
  include MonitorMixin

  attr_accessor :last_handled_build
  attr_reader :admin_e_mail_address

  def initialize(group_name, memcached_servers, options = {})
    super()
    options = {:log_level => Logger::WARN, :servers => memcached_servers}.merge(options)
    log.level = options[:log_level]
    log.formatter = Logger::Formatter.new()
    DccLogger.setLog(log)
    register_worker group_name, 0, options
    @buckets = BucketStore.new
    @admin_e_mail_address = options[:admin_e_mail_address]
  end

  def run
    log.debug "running"
    send_general_error_mail_on_failure("running worker failed") do
      process_bucket do |bucket_id|
        bucket = Bucket.find(bucket_id)
        send_bucket_error_mail_on_failure(bucket, "processing bucket failed") do
          begin
            perform_task bucket
          rescue => e
            bucket.status = 35
            bucket.save
            raise e
          end
        end
      end
    end
  end

  def perform_task(bucket)
    log.debug "performing task #{bucket}"
    logs = bucket.logs
    build = bucket.build
    project = build.project
    git = project.git
    git.update
    succeeded = true
    if last_handled_build != build.id
      succeeded = perform_rake_tasks(git.path, project.before_all_tasks(bucket.name), logs)
      self.last_handled_build = build.id
    end
    if succeeded
      succeeded &&= perform_rake_tasks(git.path, project.before_bucket_tasks(bucket.name), logs)
      succeeded &&= perform_rake_tasks(git.path, project.buckets_tasks[bucket.name], logs)
      succeeded = perform_rake_tasks(git.path, project.after_bucket_tasks(bucket.name), logs) &&
          succeeded
    end
    whole_log = ''
    logs.each do |log|
      whole_log << log.log
    end
    bucket.log = whole_log
    bucket.status = succeeded ? 10 : 40
    bucket.save
    logs.clear
    if !succeeded
      Mailer.deliver_failure_message(bucket, uri)
    else
      last_build = Build.find_last_by_project_id(bucket.build.project_id,
          :conditions => "id < #{bucket.build.id}")
      if last_build && (last_bucket = last_build.buckets.find_by_name(bucket.name)) &&
            last_bucket.status != 10
        Mailer.deliver_fixed_message(bucket, uri)
      end
    end
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
    Project.find(:all).each do |project|
      buckets = read_buckets(project)
      synchronize do
        @buckets.buckets[project.name] = buckets
      end
    end
  end

  def update_buckets
    log.debug "updating buckets"
    Project.find(:all).each do |project|
      if !@buckets.buckets[project.name] || @buckets.buckets[project.name].empty?
        buckets = read_buckets(project)
        synchronize do
          @buckets.buckets[project.name] = buckets
        end
      end
    end
  end

  def read_buckets(project)
    buckets = []
    log.debug "reading buckets for project #{project}"
    send_project_error_mail_on_failure(project, "reading buckets failed") do
      if project.wants_build?
        build_number = project.next_build_number
        build = project.builds.create(:commit => project.current_commit,
            :build_number => build_number, :leader_uri => uri)
        project.buckets_tasks.each_key do |task|
          bucket = build.buckets.create(:name => task, :status => 20)
          buckets << bucket.id
        end
        project.update_state
      end
    end
    log.debug "read buckets #{buckets.inspect}"
    buckets
  end

  def next_bucket(requestor_uri)
    bucket_spec = [@buckets.next_bucket, sleep_until_next_bucket_time]
    if bucket_id = bucket_spec[0]
      bucket = Bucket.find(bucket_id)
      bucket.worker_uri = requestor_uri
      bucket.status = 30
      bucket.save
      log.debug "deliver bucket #{bucket} to #{requestor_uri}"
    end
    bucket_spec
  end

  def send_bucket_error_mail_on_failure(bucket, subject, &block)
    send_error_mail_on_failure(:deliver_bucket_message, subject, bucket, &block)
  end

  def send_project_error_mail_on_failure(project, subject, &block)
    send_error_mail_on_failure(:deliver_project_message, subject, project, &block)
  end

  def send_general_error_mail_on_failure(subject, &block)
    send_error_mail_on_failure(:deliver_message, subject, &block)
  end

private

  def send_error_mail_on_failure(deliver_method, subject, *args, &block)
    begin
      yield
    rescue => e
      msg = "#{e.message}\n\n#{e.backtrace.join("\n")}"
      log.error msg
      if admin_e_mail_address
        deliver_args = Array.new(args)
        deliver_args << admin_e_mail_address
        deliver_args << subject
        deliver_args << msg
        Mailer.send deliver_method, *deliver_args
      end
    end
  end

  def perform_rake_tasks(path, tasks, logs)
    succeeded = true
    tasks.each {|task| succeeded = perform_rake_task(path, task, logs) && succeeded}
    succeeded
  end
end
