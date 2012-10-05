require "lib/command_line"
require "lib/dcc/logger"
require "digest/md5"

module DCC
  class Git
    include CommandLine
    include Logger


    def initialize(name, id, url, branch, fallback_branch = nil, is_dependency = false)
      # FIXME: Tests
      @name = "#{name.gsub(/[^-_a-zA-Z0-9]/, '_')}_#{id}"
      @branch = branch
      @fallback_branch = fallback_branch
      @url = url
      @is_dependency = is_dependency
      checkout
      #FIXME
    end

    attr_reader :url, :branch, :fallback_branch

    def remote_changed?
      revs = {}
      git("ls-remote", "--heads").each do |line|
        hash, head = line.split
        revs[head.gsub(%r|refs/heads/|, "origin/")] = hash
      end
      revs[remote_branch] != current_commit
    end

    def dependency?
      @is_dependency
    end

    def path
      # FIXME: Tests
      @path ||= File.expand_path("../../../tmp/#{@name}/#{sub_path}", __FILE__)
    end

    def checkout
      # FIXME: Tests
      log.debug "checking out git repository (#{path}/.git exists: #{File.exists?("#{path}/.git")})"
      clone unless File.exists?("#{path}/.git")
    end

    def clone
      # FIXME: Tests
      log.debug("cloning git repository…")
      FileUtils.rm_rf(path) if File.exists?(path)
      log.debug("→ cloning")
      git("clone", url, path, :do_not_chdir => true)
      log.debug("→ checking out")
      git("checkout", remote_branch)
      log.debug("→ update submodules")
      update_submodules
      log.debug("… cloning repository done")
    end

    def update(options = {})
      # FIXME: Tests
      log.debug("updating git repository…")
      log.debug("→ fetching")
      git("fetch")
      log.debug("→ resetting")
      git("reset", "--hard")
      log.debug("→ checking out")
      git("checkout", options[:commit] || remote_branch)
      log.debug("→ update submodules")
      update_submodules
      log.debug("→ cleanup")
      git("clean", *["-f", "-d", ("-x" if options[:clean])].compact)
      log.debug("… updating repository done")
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

    def update_submodules
      log.debug("updating git repositories submodules…")
      log.debug("→ syncing")
      git("submodule", "sync")
      log.debug("→ updating")
      git("submodule", 'update', "--init", "--recursive")
      # Submodules may break when communication with git server fails.
      # → Repair all submodules.
      log.debug("→ repairing")
      git("submodule", 'status', '--recursive').map {|line| line.split(" ")[1]}.each do |submodule|
        Dir.chdir(path) do
          Dir.chdir(submodule) do
            git("reset", "--hard", :do_not_chdir => true)
          end
        end
      end
      log.debug("… updating submodules done")
    end


    def git(operation, *args)
      # FIXME: Tests
      options = (args.last.is_a? Hash) ? args.pop : {}
      command = ["git"]
      command << operation
      command += args.compact
      error_log = File.join(path, "..", "#{@name}_git.err")
      FileUtils.rm_f(error_log)
      FileUtils.mkdir_p(File.dirname(error_log))
      FileUtils.touch(error_log)
      options[:stderr] = error_log
      options[:dir] = path unless options[:do_not_chdir]
      i = 0
      begin
        return execute(command, options) do |io|
          io.readlines.collect {|line| line.chomp}
        end
      rescue Exception => e
        if (i += 1) < 10
          log.debug("retry git command “#{command.join(' ')}” because of #{e} in 10 seconds")
          sleep 10
          retry
        else
          raise
        end
      end
    end

    def sub_path
      dependency? ? "/dependencies/#{url.gsub(/(.*:)?(.*)(\.git)?/, '\2')}" : 'repos'
    end
  end
end
