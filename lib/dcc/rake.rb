# encoding: utf-8
# FIXME Tests
require_relative "command_line"

module DCC

class Rake
  include CommandLine

  def initialize(path, log_file)
    @path = path
    @log_file = log_file
  end

  def rake(task, options = {})
    options = {:dir => @path, :stdout => @log_file, :stderr => @log_file}.merge(options)
    FileUtils.mkdir_p(File.dirname(@log_file))
    FileUtils.touch(@log_file)
    command = []
    if File.exists?(File.join(@path, 'Gemfile'))
      command << 'bundle'
      command << 'exec'
    end
    command << 'rake'
    command << task
    execute(command, options)
  end
end

end
