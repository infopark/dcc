module DccLogger
  @@log = Logger.new(STDOUT)
  @@log.level = Logger::FATAL

  def self.setLog(log)
    @@log = log
  end

  def log
    @@log
  end
end
