# encoding: utf-8

require 'logger'

module DCC
  module Logger
    @@log = ::Logger.new(STDOUT)
    @@log.level = ::Logger::FATAL

    def self.setLog(log)
      class <<log
        def context(tag)
          tags.push(tag)
          yield
        ensure
          tags.pop
        end

        def tags
          @tags ||= []
        end
      end

      log.formatter =
          proc do |severity, datetime, progname, msg|
            tags = log.send(:tags)
            sev = severity[0].upcase
            "#{sev}"\
                " [#{datetime.strftime("%Y-%m-%d %H:%M:%S.%3N")} #{Process.pid}] #{progname}:"\
                "#{" [#{tags.join("][")}]" unless tags.empty?}"\
                " #{msg}\n"
          end

      @@log = log
    end

    def log
      @@log
    end
  end
end
