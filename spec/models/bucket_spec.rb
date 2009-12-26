require File.dirname(__FILE__) + '/../spec_helper'

describe Bucket do
  fixtures :builds, :buckets, :logs

  before do
    @bucket = Bucket.find(1)
  end

  it "should have a build" do
    @bucket.build.should_not be_nil
  end

  it "should have a name" do
    @bucket.name.should == "one"
  end

  it "should have a status" do
    @bucket.status.should == 10
  end

  it "may have a log text" do
    @bucket.log.should be_nil
    Bucket.find(2).log.should == "bucket's log"
  end

  it "may have a worker uri" do
    @bucket.worker_uri.should be_nil
    Bucket.find(2).worker_uri.should == "worker's uri"
  end

  it "may have logs" do
    @bucket.logs.should be_empty
    Bucket.find(2).logs.should_not be_empty
  end

  it "may have a start time" do
    @bucket.started_at.should be_nil
    Bucket.find(2).started_at.should be_a(Time)
  end

  it "may have an end time" do
    @bucket.finished_at.should be_nil
    Bucket.find(2).finished_at.should be_a(Time)
  end
end
