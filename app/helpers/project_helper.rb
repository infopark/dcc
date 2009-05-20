module ProjectHelper
  def bucket_status(bucket)
    display_status(bucket.status)
  end

  def project_status(project)
    buckets = Bucket.find_all_by_project_id_and_commit_hash(project.id, project.last_commit)
    last_build = buckets.map {|b| b.build_number}.sort.last
    status = buckets.select {|b| b.build_number == last_build}.map {|b| b.status}.sort
    display_status(status.last == 1 ? status.first : status.last)
  end

private

  def display_status(status)
    case status
    when 0
      'pending'
    when 1
      'done'
    when 2
      'failed'
    end
  end
end
