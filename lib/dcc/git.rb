require "lib/command_line"
require "digest/md5"

module DCC
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
      git("submodule", "update", "--init", "--recursive")
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
        git("submodule", 'update', "--init", "--recursive")
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
      e = nil
      result = nil
      (1..10).each do
        e = nil
        begin
          result = execute(command, options) do |io|
            io.readlines.collect {|line| line.chomp}
          end
          break
        rescue Exception => e
        end
      end
      raise e if e
      result
    end

    def sub_path
      dependency? ? "/dependencies/#{url.gsub(/(.*:)?(.*)(\.git)?/, '\2')}" : 'repos'
    end
  end
end
