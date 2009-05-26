module ProjectHelper
  def bucket_status(bucket)
    display_status(bucket.status)
  end

  def build_status(build)
    status = build.buckets.map {|b| b.status}.sort
    display_status(status.last == 1 ? status.first : status.last)
  end

  def project_status(project)
    if last_build = Build.find_last_by_project_id_and_commit_hash(project.id, project.last_commit,
        :order => 'build_number')
      build_status(last_build)
    else
      nil
    end
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
