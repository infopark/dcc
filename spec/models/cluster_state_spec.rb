# encoding: utf-8
require 'spec_helper'

describe ClusterState do
  it "is a singleton" do
    expect { ClusterState.new }.to raise_error(NoMethodError)
    expect { ClusterState.create }.to raise_error(NoMethodError)
    expect(ClusterState.instance).to be_a(ClusterState)
  end

  it "has a minion_count" do
    expect(ClusterState.instance.minion_count).to be_a(Integer)
  end

  it "can change it's minion count" do
    i = ClusterState.instance
    i.minion_count = 13
    i.save
    expect(ClusterState.instance.minion_count).to eq 13
  end
end
