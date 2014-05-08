# encoding: utf-8
require 'forwardable'
require 'dcc/git'
require 'dcc/logger'
require 'net/https'
require 'json'

require_relative 'dependency'

class Project < ActiveRecord::Base
  include DCC::Logger

  has_many :builds, :dependent => :destroy
  has_many :dependencies, :dependent => :destroy
  validate :must_have_name, :must_have_url, :must_have_branch
  attr_accessible :name, :url, :branch, :owner

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
    @git ||= DCC::Git.new(name, id, url, branch)
  end

  def buckets_tasks
    read_config
    log.debug "providing buckets_tasks: #{@buckets_tasks.inspect}"
    @buckets_tasks
  end

  def bucket_tasks(bucket_identifier)
    log.debug "providing bucket_tasks for #{bucket_identifier}:\
        #{buckets_tasks[bucket_identifier].inspect}"
    buckets_tasks[bucket_identifier] || []
  end

  def bucket_group(bucket_identifier)
    read_config
    @buckets_groups[bucket_identifier]
  end

  def e_mail_receivers(bucket_identifier)
    read_config
    @e_mail_receivers[bucket_group(bucket_identifier)] || @e_mail_receivers[nil] || []
  end

  def ruby_version(bucket_identifier)
    read_config
    @ruby_versions[bucket_group(bucket_identifier)] || @ruby_versions[nil]
  end

  def update_dependencies
    read_config
    Dependency.where(:project_id => id).each do |d|
      if @logged_deps.include?(d.url)
        if [d.branch, d.fallback_branch] != @logged_deps[d.url]
          d.branch, d.fallback_branch = @logged_deps[d.url]
          d.save
        end
      else
        d.destroy
      end
      @logged_deps.delete(d.url)
    end
    # TODO: flush cache eleganter (löschen via #dependencies → kein explizites Flush mehr)
    dependencies(true)
    @logged_deps.each do |url, branches|
      dependencies.create(:url => url, :branch => branches[0], :fallback_branch => branches[1])
    end
  end

  def last_build
    Build.where(project_id: id).last
  end

  def build_before(build)
    builds_before(build, 1).first
  end

  def builds_before(build, count)
    build ?
        Build.where("project_id = ? AND id < ?", id, build.id).order("id DESC").first(count) : []
  end

  def next_build_number
    build = builds.where(commit_hash: current_commit).order(:build_number).last
    build ? build.build_number + 1 : 1
  end

  def before_all_code
    read_config
    @before_all_code
  end

  def before_all_tasks(bucket_identifier)
    read_config
    @before_all_tasks +
        (@before_all_tasks_of_bucket_group[bucket_group(bucket_identifier)] || [])
  end

  def before_each_bucket_group_code
    read_config
    @before_each_bucket_group_code
  end

  def before_bucket_tasks(bucket_identifier)
    read_config
    @before_bucket_tasks[bucket_group(bucket_identifier)] || []
  end

  def after_bucket_tasks(bucket_identifier)
    read_config
    @after_bucket_tasks[bucket_group(bucket_identifier)] || []
  end

  def github_user
    (m = %r#(git@github\.com:|https?://github\.com/)([^/]*)/.*#.match(url)) && m[2]
  end

  def set_e_mail_receivers(bucket_group_name, *receivers)
    if receivers.length == 1 && receivers.first.is_a?(Hash)
      receiver_map = receivers.first
      receivers = nil
      if github_user
        receivers = receiver_map[github_user.to_sym]
        unless receivers
          begin
            http = Net::HTTP.new('api.github.com', Net::HTTP.https_default_port)
            http.use_ssl = true
            receivers = JSON.parse(http.get("/users/#{github_user}").body)['email']
          rescue Exception => e
            log.warn "Could not determine E-Mail receiver from GitHub: #{e.message}"
          end
        end
      end
      receivers = receiver_map[:default] if receivers.blank?
    end
    @e_mail_receivers[bucket_group_name] = receivers ? Array(receivers) : nil
  end

  def set_ruby_version(bucket_group_name, version)
    @ruby_versions[bucket_group_name] = version
  end

  def set_rake_tasks(bucket_name, bucket_group_name, rake_tasks)
    bucket_identifier = "#{bucket_group_name}:#{bucket_name}"
    @buckets_tasks[bucket_identifier] = rake_tasks
    @buckets_groups[bucket_identifier] = bucket_group_name
  end

  def set_before_all_rake_tasks(bucket_group_name, rake_tasks)
    @before_all_tasks_of_bucket_group[bucket_group_name] = rake_tasks
  end

  def set_before_each_rake_tasks(bucket_group_name, rake_tasks)
    @before_bucket_tasks[bucket_group_name] = rake_tasks
  end

  def set_after_each_rake_tasks(bucket_group_name, rake_tasks)
    @after_bucket_tasks[bucket_group_name] = rake_tasks
  end

  def log_dependency(url, branch, fallback_branch)
    @logged_deps[url] = [branch, fallback_branch]
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
    log.debug "determining if #{self} wants build..."

    wants_build = build_requested?
    log.debug "build_requested? -> #{wants_build}"

    if git.remote_changed?
      log.debug "remote changed → updating"
      git.update :make_pristine => true
      unless wants_build
        wants_build = current_commit != last_commit
        log.debug "current_commit (#{current_commit}) != last_commit (#{last_commit})\
            → #{wants_build}"
      end
    end

    update_dependencies
    unless wants_build
      wants_build = dependencies.any? {|d| d.has_changed?}
      log.debug "dependency has changed → #{wants_build}"
    end

    unless wants_build
      read_config
      if @rebuild_if
        wants_build = @rebuild_if.call
        log.debug "rebuild_if returned #{wants_build}"
      end
    end

    wants_build
  end

  def to_s
    "#<Project; ID: #{id}, Name: #{name}>"
  end

  def for_error_log(bucket_identifier)
    read_config
    @for_error_log_code[bucket_group(bucket_identifier)]
  end

  def set_for_error_log_code(bucket_group_name, code)
    @for_error_log_code[bucket_group_name] = code
  end

  def as_json(*args)
    lb = last_build
    {
      name: name,
      id: id,
      url: url,
      branch: branch,
      build_requested: build_requested,
      last_build: lb.as_json(*args),
      last_system_error: last_system_error,
      owner: owner,
    }
  end

private

  @@inner_class = Class.new do
    def initialize(project)
      @project = project
    end
  end

  def send_notifications_to(*args)
    set_e_mail_receivers(nil, *args)
  end

  def run_with_ruby_version(version)
    set_ruby_version(nil, version)
  end

  def before_all(&block)
    @before_all_code = block if block
    Class.new(super_class = @@inner_class) do
      def performs_rake_tasks(*args)
        @project.before_all_tasks = args.flatten
      end
    end.new(self)
  end

  def before_each_bucket_group(&block)
    @before_each_bucket_group_code = block
  end

  def depends_upon(&block)
    dependency_logger = Class.new(@@inner_class) do
      def project(url, options = {})
        @project.log_dependency(url, options[:branch] || @project.branch, options[:fallback_branch])
      end
    end.new(self)
    dependency_logger.instance_eval(&block) if block_given?
    dependency_logger
  end

  def rebuild_if(&block)
    @rebuild_if = block
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

      def send_notifications_to(*args)
        @project.set_e_mail_receivers(@name, *args)
      end

      def run_with_ruby_version(version)
        @project.set_ruby_version(@name, version)
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

      def for_error_log(&block)
        @project.set_for_error_log_code(@name, block)
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

  def config_file
    @config_file ||= "#{git.path}/dcc_config.rb"
  end

  def read_config
    unless @config && git.current_commit == @config_commit
      log.debug "reading config (was empty: #{@config == nil};\
          commit changed: #{git.current_commit != @config_commit})"
      @buckets_tasks = {}
      @e_mail_receivers = {}
      @ruby_versions = {}
      @logged_deps = {}
      @before_all_tasks = []
      @buckets_groups = {}
      @before_all_tasks_of_bucket_group = {}
      @before_bucket_tasks = {}
      @after_bucket_tasks = {}
      @for_error_log_code = {}
      raise "missing config in '#{config_file}'" unless @config = File.read(config_file)
      log.debug "config read: #{@config}"
      self.instance_eval(@config, config_file)
      @config_commit = git.current_commit
    end
  end
end
