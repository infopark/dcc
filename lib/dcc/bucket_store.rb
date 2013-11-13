# encoding: utf-8
require 'set'
require_relative 'logger'

module DCC

class BucketStore
  include Logger

  def initialize
    @buckets = {}
    @workers_to_projects = {}
    @projects_to_workers = {}
  end

  def set_buckets(project, buckets)
    @buckets[project] = nil
    cleanup
    @buckets[project] = buckets
    @projects_to_workers[project] = Set.new
    log.debug "set buckets for #{project} to #{buckets.inspect}"
  end

  def next_bucket(worker_id)
    log.debug "next_bucket for #{worker_id}"
    workers = @projects_to_workers[@workers_to_projects[worker_id]]
    log.debug "#{worker_id} was in #{@workers_to_projects[worker_id]} which has #{workers.inspect}"
    workers.delete worker_id if workers
    @workers_to_projects.delete worker_id

    return if empty?

    project = nil
    @projects_to_workers.each do |k,v|
      project ||= k
      project = k if @projects_to_workers[project].size > v.size
    end
    @workers_to_projects[worker_id] = project
    @projects_to_workers[project].add worker_id
    log.debug "#{worker_id} is in #{@workers_to_projects[worker_id]} which has #{workers.inspect}"
    log.debug "popping out of #{@buckets[project].inspect}"
    @buckets[project].pop
  end

  def empty?(project = nil)
    cleanup
    project ? (!@buckets[project] || @buckets[project].empty?) : @buckets.empty?
  end

private

  def cleanup
    log.debug "clean up buckets #{@buckets.inspect}"
    @buckets.delete_if {|k,v| !v || v.empty?}
    @projects_to_workers.delete_if {|k,v| !@buckets[k]}
    @workers_to_projects.delete_if {|k,v| !@buckets[v]}
  end
end

end
