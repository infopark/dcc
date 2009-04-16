require 'forwardable'
require 'lib/git'

# FIXME: In Project noch zu implementieren
#    -> commit_no passend erzeugen (nil, 2, 3, 4...) -> nach vorhandenen buckets schauen
#    -> last_commit in der DB auf current_commit setzen
#    -> build_requested in der DB auf false setzen
#    -> buckets in der DB erzeugen
class Project < ActiveRecord::Base
  has_many :buckets
  validate :must_have_name, :must_have_url, :must_have_branch

  extend Forwardable
  def_delegators :git, :current_commit

  def must_have_name
    raise "name must not be blank" if name.blank?
  end

  def must_have_url
    raise "url must not be blank" if url.blank?
  end

  def must_have_branch
    raise "branch must not be blank" if branch.blank?
  end

  def git
    @git ||= Git.new(name, url, branch)
  end

  def tasks
    File.read("#{git.path}/dcc.tasks").split("\n")
  end

  def next_build_number
    bucket = buckets.find(:first, :conditions => "'commit' = '#{current_commit}'",
        :order => "build_number DESC")
    bucket ? bucket.build_number + 1 : 1
  end
end
