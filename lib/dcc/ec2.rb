require 'aws-sdk'
require 'json'
require 'net/http'

module DCC

class EC2
  def initialize(runs_on_ec2)
    @runs_on_ec2 = runs_on_ec2
  end

  def add_tag(name, value)
    instance.add_tag(name, value: value) if runs_on_ec2?
  end

  def remove_tag(name)
    instance.tag(name).delete if runs_on_ec2?
  end

  def neighbours
    if runs_on_ec2?
      ec2.instances.tagged('opsworks:stack').tagged_values(instance.tags["opsworks:stack"])
    else
      []
    end
  end

  private

  def runs_on_ec2?
    @runs_on_ec2
  end

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
