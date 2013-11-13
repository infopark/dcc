# encoding: utf-8
require 'forwardable'
require 'dcc/logger'

class Dependency < ActiveRecord::Base
  include DCC::Logger

  belongs_to :project
  attr_accessible :url, :branch, :fallback_branch

  extend Forwardable
  def_delegators :git, :current_commit

  def git
    @git ||= DCC::Git.new(project.name, project.id, url, branch, fallback_branch, true)
  end

  def has_changed?
    git.update
    has_changed = last_commit != current_commit
    log.debug "#{self} has changed -> #{has_changed}"
    has_changed
  end

  def update_state
    self.last_commit = current_commit
    save
  end
end
