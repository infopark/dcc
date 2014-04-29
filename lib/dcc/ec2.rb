require 'aws-sdk'
require 'json'
require 'net/http'

module DCC

module EC2
  class << self
    def add_tag(name, value)
      instance.add_tag(name, value: value)
    end

    def neighbours
      ec2.instances.tagged('opsworks:stack').tagged_values(instance.tags["opsworks:stack"]).
          reject {|i| i.id == instance.id }
    end

    private

    def meta_data
      @meta_data ||= JSON.parse(Net::HTTP.new('169.254.169.254').
          get("/latest/dynamic/instance-identity/document").body)
    end

    def ec2
      @ec2 ||= AWS::EC2.new(region: meta_data['region'])
    end

    def instance
      @instance ||= ec2.instances[meta_data['instanceId']]
    end
  end
end

end
