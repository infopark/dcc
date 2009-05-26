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
    @bucket.status.should == 1
  end

  it "may have a log text" do
    @bucket.log.should be_nil
    Bucket.find(2).log.should == "bucket's log"
  end

  it "may have logs" do
    @bucket.logs.should be_empty
    Bucket.find(2).logs.should_not be_empty
  end
end
