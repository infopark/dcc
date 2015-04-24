# encoding: utf-8

require 'dcc/worker'

module DCC

  class Worker
    attr_accessor :buckets

    def cleanup
    end

    def log_polling_intervall
      return 0.1
    end

    def as_dictator(memcache_client)
      yield
    end
  end

end
