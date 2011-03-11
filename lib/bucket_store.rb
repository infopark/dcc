require 'set'

class BucketStore
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
  end

  def next_bucket(worker_id)
    workers = @projects_to_workers[@workers_to_projects[worker_id]]
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
    @buckets[project].pop
  end

  def empty?(project = nil)
    cleanup
    project ? (!@buckets[project] || @buckets[project].empty?) : @buckets.empty?
  end

private

  def cleanup
    @buckets.delete_if {|k,v| !v || v.empty?}
    @projects_to_workers.delete_if {|k,v| !@buckets[k]}
    @workers_to_projects.delete_if {|k,v| !@buckets[v]}
  end
end
