module ProjectHelper
  def last_build(project)
    Build.find_last_by_project_id_and_commit_hash(project.id, project.last_commit,
        :order => 'build_number')
  end
end
