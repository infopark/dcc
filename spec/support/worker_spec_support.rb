# encoding: utf-8

require 'dcc/worker'

module DCC

  class Worker
    attr_accessor :buckets
    attr_reader :memcache_client

    def cleanup
    end

    def log_polling_intervall
      return 0.1
    end

    def as_dictator
      yield
    end
  end

end
