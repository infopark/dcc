require File.dirname(__FILE__) + '/../spec_helper'

describe ProjectHelper do
  describe 'build_status' do
    before do
      @succeeded_bucket = mock('bucket', :status => 10)
      @pending_bucket = mock('bucket', :status => 20)
      @inwork_bucket = mock('bucket', :status => 30)
      @processing_failed_bucket = mock('bucket', :status => 30)
      @failed_bucket = mock('bucket', :status => 40)
      @build = Build.new
      helper.extend ApplicationHelper
    end

    it "should return 'pending' if no bucket failed or is in work and at least one is pending" do
      @build.stub!(:buckets => [@succeeded_bucket, @pending_bucket, @succeeded_bucket])
      helper.build_status(@build).should == 'pending'
    end

    it "should return 'in work' if no bucket failed and at least one is in work" do
      @build.stub!(:buckets =>
          [@succeeded_bucket, @pending_bucket, @inwork_bucket, @succeeded_bucket])
      helper.build_status(@build).should == 'in work'
    end

    it "should return 'processing failed' if no bucket failed and at least one's processing failed" do
      @build.stub!(:buckets => [@succeeded_bucket, @pending_bucket, @inwork_bucket,
          @processing_failed_bucket, @succeeded_bucket])
      helper.build_status(@build).should == 'in work'
    end

    it "should return 'done' iff all buckets are done" do
      @build.stub!(:buckets => [@succeeded_bucket, @succeeded_bucket])
      helper.build_status(@build).should == 'done'
    end

    it "should return 'failed' if at least one bucket failed" do
      @build.stub!(:buckets => [@succeeded_bucket, @failed_bucket, @pending_bucket, @inwork_bucket,
          @processing_failed_bucket])
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
