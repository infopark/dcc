require File.dirname(__FILE__) + '/../spec_helper'

describe ProjectHelper do
  describe 'bucket_status' do
    it "should return 'pending' if bucket is pending" do
      helper.bucket_status(mock('bucket', :status => 0)).should == 'pending'
    end

    it "should return 'done' if bucket was successfully done" do
      helper.bucket_status(mock('bucket', :status => 1)).should == 'done'
    end

    it "should return 'failed' if bucket has failed" do
      helper.bucket_status(mock('bucket', :status => 2)).should == 'failed'
    end
  end

  describe 'project_status' do
    before do
      @succeeded_bucket = mock('bucket', :status => 1, :build_number => 6)
      @pending_bucket = mock('bucket', :status => 0, :build_number => 6)
      @failed_bucket = mock('bucket', :status => 2, :build_number => 6)
      @project = Project.new
      @project.last_commit = 'der commit'
      @project.id = 666
    end

    it "should return 'pending' if no bucket failed and at least one is pending" do
      Bucket.stub!(:find_all_by_project_id_and_commit_hash).with(666, 'der commit').and_return(
          [@succeeded_bucket, @pending_bucket, @succeeded_bucket])
      helper.project_status(@project).should == 'pending'
    end

    it "should return 'done' iff all buckets are done" do
      Bucket.stub!(:find_all_by_project_id_and_commit_hash).with(666, 'der commit').and_return(
          [@succeeded_bucket, @succeeded_bucket])
      helper.project_status(@project).should == 'done'
    end

    it "should return 'failed' if at least one bucket failed" do
      Bucket.stub!(:find_all_by_project_id_and_commit_hash).with(666, 'der commit').and_return(
          [@succeeded_bucket, @failed_bucket, @pending_bucket])
      helper.project_status(@project).should == 'failed'
    end

    it "should return the state of the latest build only" do
      Bucket.stub!(:find_all_by_project_id_and_commit_hash).with(666, 'der commit').and_return(
          [@succeeded_bucket, @failed_bucket, @pending_bucket])
      @pending_bucket.stub!(:build_number).and_return 1
      @failed_bucket.stub!(:build_number).and_return 3
      helper.project_status(@project).should == 'done'
    end
  end
end
