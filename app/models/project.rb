require 'forwardable'
require 'lib/git'

class Project < ActiveRecord::Base
  has_many :builds, :dependent => :destroy
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
    read_config['tasks']
  end

  def e_mail_receivers
    configured_email = read_config['email']
    email = if configured_email
      configured_email.is_a?(Array) ? configured_email : [configured_email]
    else
      ['develop@infopark.de']
    end
  end

  def next_build_number
    build = builds.find(:first, :conditions => %Q(commit_hash = '#{current_commit}'),
        :order => "build_number DESC")
    build ? build.build_number + 1 : 1
  end

private

  def read_config
    config_file = "#{git.path}/dcc.yml"
    raise "missing config in '#{config_file}'" unless config = YAML::load(File.read(config_file))
    config
  end
end
