# encoding: utf-8
require File.dirname(__FILE__) + '/../spec_helper'

describe Bucket do
  fixtures :builds, :buckets, :logs

  before do
    @bucket = Bucket.find(1)
  end

  it "should have a build" do
    expect(@bucket.build).not_to be_nil
  end

  it "should have a name" do
    expect(@bucket.name).to eq("one")
  end

  it "should have a status" do
    expect(@bucket.status).to eq(10)
  end

  it "may have a log text" do
    expect(Bucket.select(:log).find(1).log).to be_nil
    expect(Bucket.select(:log).find(2).log).to eq("bucket's log")
  end

  it "may have a worker uri" do
    expect(@bucket.worker_uri).to be_nil
    expect(Bucket.find(2).worker_uri).to eq("worker's uri")
  end

  it "may have logs" do
    expect(@bucket.logs).to be_empty
    expect(Bucket.find(2).logs).not_to be_empty
  end

  it "may have a start time" do
    expect(@bucket.started_at).to be_nil
    expect(Bucket.find(2).started_at).to be_a(Time)
  end

  it "may have an end time" do
    expect(@bucket.finished_at).to be_nil
    expect(Bucket.find(2).finished_at).to be_a(Time)
  end

  it "may have an error log" do
    expect(Bucket.select(:error_log).find(1).error_log).to be_nil
    expect(Bucket.select(:error_log).find(2).error_log).to eq("bucket's error log")
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
      expect(@unsorted_buckets.sort).to eq(@sorted_buckets)
    end

    it "should return nil when compared with non bucket" do
      expect(@bucket.<=>("nix bucket")).to be_nil
    end
  end

  describe "when building error log" do
    before do
      allow(@bucket.build).to receive(:project).and_return(@project = double('project', :name => 'p'))
      allow(@bucket).to receive(:finished_at).and_return Time.now
      allow(@project).to receive(:for_error_log).and_return(double('code', :call => 'nix da'))
      allow(@bucket).to receive(:log).and_return('the log')
    end

    it "should not do anything when project has no “for_error_log” code" do
      allow(@project).to receive(:for_error_log).and_return nil
      expect(@bucket).not_to receive(:error_log=)
      expect(@bucket).not_to receive(:save)
      @bucket.build_error_log
    end

    it "should raise an error if it has not finished yet" do
      allow(@bucket).to receive(:finished_at).and_return nil
      expect {@bucket.build_error_log}.to raise_error(NotFinishedYet)
    end

    it "should store the outcome of the “for_error_log” code for the log into the database" do
      expect(@project).to receive(:for_error_log).with('one').and_return(code = double('error_log_code'))
      expect(code).to receive(:call).with('the log').and_return('the errors')
      expect(@bucket).to receive(:error_log=).with("the errors").ordered
      expect(@bucket).to receive(:save).ordered
      @bucket.build_error_log
    end
  end

  describe "#as_json" do
    it "returns the bucket as json serializable structure" do
      expect(@bucket.as_json.with_indifferent_access).to eq({
        id: 1,
        name: "one",
        status: 10,
        started_at: nil,
        finished_at: nil,
        worker_uri: nil,
        worker_hostname: nil,
      }.with_indifferent_access)
    end
  end
end
