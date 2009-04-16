require 'politics'
require 'politics/static_queue_worker'
require 'app/models/project'
require 'app/models/bucket'

class DCCWorker
  include Politics::StaticQueueWorker

  def initialize(memcached_servers, options = {})
# FIXME: Default-LogLevel -> WARN
    options = {:log_level => Logger::DEBUG, :servers => memcached_servers, :iteration_length => 10
        }.merge(options)
    log.level = options[:log_level]
    register_worker 'worker', 0, options
  end

  def run
    process_bucket do |bucket|
      perform_task bucket
    end
  end

  def perform_task(bucket)
    log.debug "#{@uri} performing task #{bucket}"
# FIXME: tu was
# -> arbeit tun (und dabei logs häppchenweise schreiben -> fork mit loop)
# -> logs archivieren & status auf ok bzw. failed setzen
puts "FIXME: mach mal #{bucket}"
sleep 0.5
  end

  def initialize_buckets
    log.debug "#{@uri} initializing buckets"
    @buckets = read_buckets
  end

  def read_buckets
    buckets = []
    log.debug "#{@uri} reading buckets"
    Project.find(:all).each do |project|
      log.debug "#{@uri} reading buckets for project #{project}"
      if project.build_requested? || project.current_commit != project.last_commit
        build_number = project.next_build_number
        log.debug "#{@uri} set up buckets for project #{project} with build_number #{build_number}\
            because #{project.build_requested} ||\
            #{project.current_commit} != #{project.last_commit}"
        project.tasks.each do |task|
          buckets << project.buckets.create(:commit => project.current_commit,
              :build_number => build_number, :name => task, :status => 0)
        end
        update_project project
      end
    end
    log.debug "#{@uri} read buckets #{buckets.inspect}"
    buckets
  end

  def update_project(project)
    log.debug "#{@uri} updating project #{project} with commit #{project.current_commit}"
    project.last_commit = project.current_commit
    project.build_requested = false
    project.save
    log.debug "#{@uri} project's last commit is now #{project.last_commit}"
  end
end
