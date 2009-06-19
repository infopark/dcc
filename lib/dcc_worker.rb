require 'politics'
require 'politics/static_queue_worker'
require 'app/models/project'
require 'app/models/build'
require 'app/models/bucket'
require 'app/models/log'
require 'lib/rake'
require 'lib/mailer'

class DCCWorker
  include Politics::StaticQueueWorker

  attr_accessor :last_handled_build

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
      bucket = Bucket.find(bucket_id)
      begin
        perform_task bucket
      rescue Exception => e
        bucket.status = 35
        bucket.save
        log.error "failed to process #{bucket}: #{e.message}"
        log.error e.backtrace.join("\n")
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
      Mailer.deliver_failure_message(bucket, @uri)
    else
      last_build = Build.find_last_by_project_id(bucket.build.project_id,
          :conditions => "id < #{bucket.build.id}")
      if last_build && (last_bucket = last_build.buckets.find_by_name(bucket.name)) &&
            last_bucket.status != 10
        Mailer.deliver_fixed_message(bucket, @uri)
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
    @buckets = read_buckets
  end

  def read_buckets
    buckets = []
    log.debug "reading buckets"
    Project.find(:all).each do |project|
      log.debug "reading buckets for project #{project}"
      if project.build_requested? || project.current_commit != project.last_commit ||
          dependency_changed(project)
        build_number = project.next_build_number
        log.debug "set up buckets for project #{project} with build_number #{build_number}" +
            " because #{project.build_requested?} ||" +
            " #{project.current_commit} != #{project.last_commit}"
        build = project.builds.create(:commit => project.current_commit, :build_number => build_number)
        project.buckets_tasks.each_key do |task|
          bucket = build.buckets.create(:name => task, :status => 20)
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
    project.dependency_gits.each do |git|
      dependency = project.dependencies.find_by_url(git.url)
      if dependency
        dependency.last_commit = git.current_commit
        dependency.save
      else
        project.dependencies.create(:url => git.url, :last_commit => git.current_commit)
      end
    end
  end

  def next_bucket(requestor_uri)
    bucket_spec = super
    if bucket_id = bucket_spec[0]
      bucket = Bucket.find(bucket_id)
      bucket.worker_uri = requestor_uri
      bucket.status = 30
      bucket.save
      log.debug "deliver bucket #{bucket} to #{requestor_uri}"
    end
    bucket_spec
  end

private

  def dependency_changed(project)
    # TODO: die ganze Dependency-Logik ins Projekt verschieben und dort besser Unit-Testen
    # -> z.B. daß der current_commit für das dependency-Update hier gemerkt wird - dadurch führen
    # Updates während des Builds auch wieder zu rebuilds.
    # Momentan ist das _nicht_ so!
    project.dependency_gits.any? do |git|
      dependency = project.dependencies.find_by_url(git.url)
      !dependency || git.current_commit != dependency.last_commit
    end
  end

  def perform_rake_tasks(path, tasks, logs)
    succeeded = true
    tasks.each {|task| succeeded = perform_rake_task(path, task, logs) && succeeded}
    succeeded
  end
end
