require 'politics'
require 'politics/static_queue_worker'
require 'app/models/project'
require 'app/models/bucket'

class DCCWorker
  include Politics::StaticQueueWorker

  def initialize(memcached_servers, options = {})
# FIXME: Default-LogLevel -> WARN
    options = {:log_level => Logger::INFO, :servers => memcached_servers, :iteration_length => 10
        }.merge(options)
    log.level = options[:log_level]
    register_worker 'worker', 0, options
  end

  def run
    process_bucket do |bucket|
      perform_task *bucket
    end
  end

  def perform_task(url, branch, sha1, build_no)
# FIXME: tu was
# -> arbeit tun (und dabei logs häppchenweise schreiben -> fork mit loop)
# -> logs archivieren & status auf ok bzw. failed setzen
puts "FIXME: mach mal #{bucket}"
sleep 0.5
  end

  def initialize_buckets
    @buckets = read_buckets
  end

  def read_buckets
    buckets = []
    Project.find(:all).each do |project|
      if project.build_requested? || project.current_commit != project.last_commit
        build_number = project.next_build_number
        project.tasks.each do |task|
          buckets << [project.url, project.branch, project.current_commit, build_number, task]
          Bucket.new(:project_id => project.project_id, :commit => project.current_commit,
              :build_number => build_number, :name => task, :status => 0).save
        end
        update_project project
      end
    end
    buckets
  end

  def update_project(project)
    project.last_commit = project.current_commit
    project.build_requested = false
    project.save
  end
end
