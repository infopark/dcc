module ProjectHelper
  def last_build(project)
    Build.find_last_by_project_id_and_commit_hash(project.id, project.last_commit,
        :order => 'build_number')
  end

  def project_display_status(project)
    build = last_build(project)
    build_display_status(build) if build
  end

  def project_status(project)
    build = last_build(project)
    build_status(build) if build
  end
end
