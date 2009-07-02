module ProjectHelper
  def bucket_status(bucket)
    display_status(bucket.status)
  end

  def build_status(build)
    display_status(build.buckets.map {|b| b.status}.sort.last)
  end

  def project_status(project)
    last_build = Build.find_last_by_project_id_and_commit_hash(project.id, project.last_commit,
        :order => 'build_number')
    build_status(last_build) if last_build
  end

  def build_display_value(build)
    "#{build.identifier} verwaltet von #{build.leader_uri}"
  end

private

  def display_status(status)
    case status
    when 10
      'done'
    when 20
      'pending'
    when 30
      'in work'
    when 35
      'processing failed'
    when 40
      'failed'
    else
      "unknown status #{status}"
    end
  end
end
