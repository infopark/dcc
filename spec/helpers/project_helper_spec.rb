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

  describe 'build_status' do
    before do
      @succeeded_bucket = mock('bucket', :status => 1)
      @pending_bucket = mock('bucket', :status => 0)
      @failed_bucket = mock('bucket', :status => 2)
      @build = Build.new
    end

    it "should return 'pending' if no bucket failed and at least one is pending" do
      @build.stub!(:buckets => [@succeeded_bucket, @pending_bucket, @succeeded_bucket])
      helper.build_status(@build).should == 'pending'
    end

    it "should return 'done' iff all buckets are done" do
      @build.stub!(:buckets => [@succeeded_bucket, @succeeded_bucket])
      helper.build_status(@build).should == 'done'
    end

    it "should return 'failed' if at least one bucket failed" do
      @build.stub!(:buckets => [@succeeded_bucket, @failed_bucket, @pending_bucket])
      helper.build_status(@build).should == 'failed'
    end
  end

  describe 'project_status' do
    before do
      @project = Project.new
      @project.last_commit = 'der commit'
      @project.id = 666
    end

    it "should return the last build's status" do
      Build.stub!(:find_last_by_project_id_and_commit_hash).with(666, 'der commit',
          :order => 'build_number').and_return('last build')
      helper.stub!(:build_status).with('last build').and_return("last build's status")
      helper.project_status(@project).should == "last build's status"
    end
  end
end
