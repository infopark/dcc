# encoding: utf-8
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
    Bucket.select(:log).find(1).log.should be_nil
    Bucket.select(:log).find(2).log.should == "bucket's log"
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

  it "may have an error log" do
    Bucket.select(:error_log).find(1).error_log.should be_nil
    Bucket.select(:error_log).find(2).error_log.should == "bucket's error log"
  end

  describe "when being sorted" do
    before do
      b1 = Bucket.new; b1.name = "bucket 1"
      b2 = Bucket.new; b2.name = "bucket 2"
      b3 = Bucket.new; b3.name = "bucket 3"
      b4 = Bucket.new; b4.name = "bucket 4"
      b5 = Bucket.new; b5.name = "bucket 5"
      @unsorted_buckets = [b5, b2, b1, b3, b4]
      @sorted_buckets = [b1, b2, b3, b4, b5]
    end

    it "should be sorted by the name" do
      @unsorted_buckets.sort.should == @sorted_buckets
    end

    it "should return nil when compared with non bucket" do
      @bucket.<=>("nix bucket").should be_nil
    end
  end

  describe "when building error log" do
    before do
      @bucket.build.stub(:project).and_return(@project = double('project', :name => 'p'))
      @bucket.stub(:finished_at).and_return Time.now
      @project.stub(:for_error_log).and_return(double('code', :call => 'nix da'))
      @bucket.stub(:log).and_return('the log')
    end

    it "should not do anything when project has no “for_error_log” code" do
      @project.stub(:for_error_log).and_return nil
      @bucket.should_not_receive(:error_log=)
      @bucket.should_not_receive(:save)
      @bucket.build_error_log
    end

    it "should raise an error if it has not finished yet" do
      @bucket.stub(:finished_at).and_return nil
      lambda {@bucket.build_error_log}.should raise_error(NotFinishedYet)
    end

    it "should store the outcome of the “for_error_log” code for the log into the database" do
      @project.should_receive(:for_error_log).with('one').and_return(code = double('error_log_code'))
      code.should_receive(:call).with('the log').and_return('the errors')
      @bucket.should_receive(:error_log=).with("the errors").ordered
      @bucket.should_receive(:save).ordered
      @bucket.build_error_log
    end
  end

  describe "#as_json" do
    it "returns the bucket as json serializable structure" do
      @bucket.as_json.with_indifferent_access.should == {
        id: 1,
        name: "one",
        status: 10,
        started_at: nil,
        finished_at: nil,
        worker_uri: nil,
        worker_hostname: nil,
      }.with_indifferent_access
    end
  end
end
