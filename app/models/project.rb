require 'forwardable'
require 'lib/git'
require 'lib/mailer'
require 'lib/dcc_logger'
require 'app/models/dependency'

class Project < ActiveRecord::Base
  include DccLogger

  has_many :builds, :dependent => :destroy
  has_many :dependencies, :dependent => :destroy
  validate :must_have_name, :must_have_url, :must_have_branch

  attr_writer :before_all_tasks

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

  def buckets_tasks
    read_config
    @buckets_tasks
  end

  def e_mail_receivers
    read_config
    @e_mail_receivers || []
  end

  def update_dependencies
    @logged_deps = {}
    read_config
    Dependency.find_all_by_project_id(id).each do |d|
      if @logged_deps.include?(d.url)
        if d.branch != @logged_deps[d.url]
          d.branch = @logged_deps[d.url]
          d.save
        end
      else
        d.destroy
      end
      @logged_deps.delete(d.url)
    end
    @logged_deps.each do |url, branch|
      dependencies.create(:url => url, :branch => branch)
    end
  end

  def next_build_number
    build = builds.find(:first, :conditions => %Q(commit_hash = '#{current_commit}'),
        :order => "build_number DESC")
    build ? build.build_number + 1 : 1
  end

  def before_all_tasks(bucket_identifier)
    read_config
    (@before_all_tasks || []) + (_before_all_tasks[buckets_groups[bucket_identifier]] || [])
  end

  def before_bucket_tasks(bucket_identifier)
    read_config
    _before_bucket_tasks[buckets_groups[bucket_identifier]] || []
  end

  def after_bucket_tasks(bucket_identifier)
    read_config
    _after_bucket_tasks[buckets_groups[bucket_identifier]] || []
  end

  def set_rake_tasks(bucket_name, bucket_group_name, rake_tasks)
    bucket_identifier = "#{bucket_group_name}:#{bucket_name}"
    (@buckets_tasks ||= {})[bucket_identifier] = rake_tasks
    buckets_groups[bucket_identifier] = bucket_group_name
  end

  def set_before_all_rake_tasks(bucket_group_name, rake_tasks)
    _before_all_tasks[bucket_group_name] = rake_tasks
  end

  def set_before_each_rake_tasks(bucket_group_name, rake_tasks)
    _before_bucket_tasks[bucket_group_name] = rake_tasks
  end

  def set_after_each_rake_tasks(bucket_group_name, rake_tasks)
    _after_bucket_tasks[bucket_group_name] = rake_tasks
  end

  def log_dependency(url, branch)
    (@logged_deps || {})[url] = branch
  end

  def update_state
    self.last_commit = current_commit
    self.build_requested = false
    save
    dependencies.each do |dependency|
      dependency.update_state
    end
  end

  def wants_build?
    update_dependencies
    log.debug "determining if #{self} wants build..."
    wants_build = build_requested?
    log.debug "build_requested? -> #{wants_build}"
    unless wants_build
      cc = current_commit
      lc = last_commit
      wants_build = cc != lc
      log.debug "current_commit (#{cc}) != last_commit (#{lc}) -> #{wants_build}"
    end
    unless wants_build
      wants_build = dependencies.any? {|d| d.has_changed?}
      log.debug "dependency has changed -> #{wants_build}"
    end
    wants_build
  end

  def to_s
    "#<Project; ID: #{id}, Name: #{name}>"
  end

private

  def buckets_groups
    @buckets_groups ||= {}
  end

  def _before_all_tasks
    @before_all_tasks_of_bucket_group ||= {}
  end

  def _before_bucket_tasks
    @before_bucket_tasks ||= {}
  end

  def _after_bucket_tasks
    @after_bucket_tasks ||= {}
  end

  @@inner_class = Class.new do
    def initialize(project)
      @project = project
    end
  end

  def send_notifications_to(*args)
    @e_mail_receivers = args.flatten
  end

  def before_all
    Class.new(super_class = @@inner_class) do
      def performs_rake_tasks(*args)
        @project.before_all_tasks = args.flatten
      end
    end.new(self)
  end

  def depends_upon(&block)
    dependency_logger = Class.new(@@inner_class) do
      def project(url, options = {})
        @project.log_dependency(url, options[:branch] || @project.branch)
      end
    end.new(self)
    dependency_logger.instance_eval(&block) if block_given?
    dependency_logger
  end

  def buckets(name, &block)
    Class.new(@@inner_class) do
      @@bucket_group_inner_class = Class.new(@@inner_class) do
        def initialize(project, bucket_group_name)
          @bucket_group_name = bucket_group_name
          super project
        end
      end

      def initialize(project, name)
        @name = name.to_s
        super project
      end

      def before_all
        Class.new(@@bucket_group_inner_class) do
          def performs_rake_tasks(*args)
            @project.set_before_all_rake_tasks(@bucket_group_name, args.flatten)
          end
        end.new(@project, @name)
      end

      def before_each_bucket
        Class.new(@@bucket_group_inner_class) do
          def performs_rake_tasks(*args)
            @project.set_before_each_rake_tasks(@bucket_group_name, args.flatten)
          end
        end.new(@project, @name)
      end

      def after_each_bucket
        Class.new(@@bucket_group_inner_class) do
          def performs_rake_tasks(*args)
            @project.set_after_each_rake_tasks(@bucket_group_name, args.flatten)
          end
        end.new(@project, @name)
      end

      def bucket(name)
        Class.new(@@bucket_group_inner_class) do
          def initialize(project, bucket_group_name, name)
            @name = name.to_s
            super project, bucket_group_name
          end

          def performs_rake_tasks(*args)
            @project.set_rake_tasks(@name, @bucket_group_name, args.flatten)
          end
        end.new(@project, @name, name)
      end
    end.new(self, name).instance_eval(&block)
  end

  def read_config
    config_file = "#{git.path}/dcc_config.rb"
    raise "missing config in '#{config_file}'" unless config = File.read(config_file)
    self.instance_eval(config)
  end
end
