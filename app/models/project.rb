require 'forwardable'
require 'lib/git'

class Project < ActiveRecord::Base
  has_many :buckets, :dependent => :destroy
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
    YAML::load(File.read("#{git.path}/dcc.tasks"))
  end

  def next_build_number
    bucket = buckets.find(:first, :conditions => %Q("commit" = '#{current_commit}'),
        :order => "build_number DESC")
    bucket ? bucket.build_number + 1 : 1
  end
end
