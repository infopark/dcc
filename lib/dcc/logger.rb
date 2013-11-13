# encoding: utf-8
module DCC
  module Logger
    @@log = ::Logger.new(STDOUT)
    @@log.level = ::Logger::FATAL

    def self.setLog(log)
      class <<log
        def debug(msg = nil, &block)
          add(::Logger::DEBUG, msg, "#{Kernel.caller.first}", &block)
        end
      end
      @@log = log
    end

    def log
      @@log
    end
  end
end
