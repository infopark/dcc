require File.dirname(__FILE__) + '/../spec_helper'

describe ApplicationHelper do
  describe 'bucket_status' do
    it "should return 'pending' if bucket is pending" do
      helper.bucket_status(mock('bucket', :status => 20)).should == 'pending'
    end

    it "should return 'in work' if bucket is in work" do
      helper.bucket_status(mock('bucket', :status => 30)).should == 'in work'
    end

    it "should return 'done' if bucket was successfully done" do
      helper.bucket_status(mock('bucket', :status => 10)).should == 'done'
    end

    it "should return 'processing failed' if bucket processing has failed" do
      helper.bucket_status(mock('bucket', :status => 35)).should == 'processing failed'
    end

    it "should return 'failed' if bucket has failed" do
      helper.bucket_status(mock('bucket', :status => 40)).should == 'failed'
    end
  end

  describe 'build_display_value' do
    before do
      @build = mock('build', :identifier => 'build_identifier', :leader_uri => 'leader_uri')
    end

    it "should return the display value containing the identifier and the leader_uri" do
      helper.build_display_value(@build).should == "build_identifier verwaltet von leader_uri"
    end
  end

  describe 'bucket_display_value' do
    before do
      @bucket = mock('bucket', :name => 'bucket_name', :worker_uri => 'worker_uri')
    end

    it "should return the display value containing the name and the worker_uri" do
      helper.bucket_display_value(@bucket).should == "bucket_name auf worker_uri"
    end

    it "should return the name only if worker_uri is nil" do
      @bucket.stub!(:worker_uri).and_return nil
      helper.bucket_display_value(@bucket).should == "bucket_name"
    end
  end
end
