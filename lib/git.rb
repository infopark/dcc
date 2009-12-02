require "lib/command_line"
require "digest/md5"

class Git
  include CommandLine

  def initialize(name, url, branch, fallback_branch = nil, is_dependency = false)
    # FIXME: Tests
    @name = "#{name.gsub(/[^-_a-zA-Z0-9]/, '_')}_#{Digest::MD5.hexdigest(name)}"
    @branch = branch
    @fallback_branch = fallback_branch
    @url = url
    @is_dependency = is_dependency
    checkout
    #FIXME
  end

  attr_reader :url, :branch, :fallback_branch

  def dependency?
    @is_dependency
  end

  def path
    # FIXME: Tests
    "/var/tmp/dcc/#{@name}/#{sub_path}"
  end

  def checkout
    # FIXME: Tests
    clone unless File.exists?("#{path}/.git")
  end

  def clone
    # FIXME: Tests
    FileUtils.rm_rf(path) if File.exists?(path)
    git("clone", url, path, :do_not_chdir => true)
    git("checkout", remote_branch)
    git("submodule", "update", "--init")
  end

  def fetch
    # FIXME: Tests
    git("fetch")
  end

  def update(commit = nil)
    # FIXME: Tests
    fetch
    Dir.chdir(path) do
      git("checkout", commit || remote_branch)
      git("reset", "--hard")
      git("submodule", 'update', "--init")
      git("clean", "-f", "-d")
    end
  end

  def current_commit
    # FIXME: Tests
    git("log", '--pretty=format:%H', '-n', '1')[0]
  end

  def remote_branch
    rb = nil
    return rb if branch_exists?(rb = "origin/#{branch}")
    return rb if branch_exists?(rb = "origin/#{fallback_branch}")
    raise "neither branch '#{branch}' nor fallback branch '#{fallback_branch}' exist at #{url}"
  end

  private

  def branch_exists?(branch)
    git("branch", "-r").map {|l| l.strip}.include?(branch)
  end

  def git(operation, *args)
    # FIXME: Tests
    options = (args.last.is_a? Hash) ? args.pop : {}
    command = ["git"]
    command << operation
    command += args.compact
    error_log = File.expand_path(File.join(path, "..", "#{@name}_git.err"))
    FileUtils.rm_f(error_log)
    FileUtils.mkdir_p(File.dirname(error_log))
    FileUtils.touch(error_log)
    options[:stderr] = error_log
    options[:dir] = path unless options[:do_not_chdir]
    execute(command, options) do |io|
      io.readlines.collect {|line| line.chomp}
    end
  end

  def sub_path
    dependency? ? "/dependencies/#{url.gsub(/(.*:)?(.*)(\.git)?/, '\2')}" : 'repos'
  end
end

# FIXME: kopiert aus cc.rb
#require 'builder_error'
#require 'date'
#
#class GitRevision < Revision
#  attr_reader :hash, :short_hash, :message, :committer, :committed_date
#
#  def initialize(hash, short_hash, message, committer, committed_date)
#    @hash = hash
#    @short_hash = short_hash
#    @message = message
#    @committer = committer
#    @committed_date = committed_date
#  end
#
#  alias :number :short_hash
#  alias :committed_by :committer
#  alias :time :committed_date
#end
#
#class Git
#  include CommandLine
#
#  attr_accessor :url, :path, :username, :password, :branch, :project
#
#  def initialize(options = {})
#    @url = options.delete(:url)
#    @path = options.delete(:path) || "."
#    @username = options.delete(:username)
#    @password = options.delete(:password)
#    @interactive = options.delete(:interactive)
#    @error_log = options.delete(:error_log)
#    @branch = options.delete(:branch) || "master"
#    @repository = options.delete(:repository) || "origin"
#    case RUBY_PLATFORM
#    when /win/
#      @include_submodules = false
#    else
#      @include_submodules = true
#    end
#  end
#
#  def latest_revision
#    hash, short_hash, committer, committed_date =
#        *git("log", %W(--pretty=format:%H%n%h%n%cn%n%cd -n 1 #{@branch}))
#    build = Build.new(@project, short_hash)
#    last_build = @project.last_complete_build || build
#    message = git("log", %W(--pretty=oneline --abbrev-commit #{last_build.revision}..#{short_hash}))
#    GitRevision.new(hash, short_hash, message, committer,
#        DateTime.strptime(committed_date, '%a %b %d %H:%M:%S %Y %z'))
#  end
#
#  def fetch
#    git("fetch")
#  end
#
#  def update(revision = nil)
#    fetch
#    Dir.chdir(path) do
#      git("reset", ["--hard", "origin/#{@branch}"])
#      if @include_submodules
#        git("submodule", ['update', "--init"])
#      end
#      git("clean", ["-f", "-d"])
#    end
#  end
#
#  def up_to_date?(reasons = [], revision_number = latest_revision.number)
#    fetch
#    return true if git("rev-parse", [@branch, "origin/#{@branch}"]).uniq.length == 1
#    update
#    reasons << latest_revision
#    false
#  end
#
#  def checkout
#    return clone unless File.exists?("#{path}/.git")
#  end
#
#  def clone(stdout = $stdout)
#    FileUtils.rm_rf(path) if File.exists?(@path)
#    git("clone", [@url, @path], :execute_locally => false)
#    git("checkout", git("name-rev", ["--name-only", @branch]).include?(@branch) ? [@branch] :
#        %W(-t -b #{@branch} origin/#{@branch}))
#    if @include_submodules
#      git("submodule", ["update", "--init"])
#    end
#  end
#
#  def git(operation, arguments = [], options = {}, &block)
#    command = ["git"]
#    command << operation
#    command += arguments.compact
#    command
#    error_log = File.expand_path(self.error_log)
#    FileUtils.rm_f(error_log)
#    FileUtils.touch(error_log)
#    if options[:execute_locally] != false
#      Dir.chdir(path) do
#        execute_with_error_log(command, error_log, options, &block)
#      end
#    else
#      execute_with_error_log(command, error_log, options, &block)
#    end
#  end
#
#  def execute_with_error_log(command, error_log, options = {}, &block)
#    execute(command, :stderr => error_log) do |io|
#      io.readlines.collect {|line| line.chomp}
#    end
#  end
#
#  def error_log
#    @error_log ? @error_log : File.join(@path, "..", "git.err")
#  end
#end
