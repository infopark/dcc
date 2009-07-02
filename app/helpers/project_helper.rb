module ProjectHelper
  def build_status(build)
    display_status(build.buckets.map {|b| b.status}.sort.last)
  end

  def project_status(project)
    last_build = Build.find_last_by_project_id_and_commit_hash(project.id, project.last_commit,
        :order => 'build_number')
    build_status(last_build) if last_build
  end
end
