require File.dirname(__FILE__) + '/../spec_helper'

describe ApplicationHelper do
  describe 'bucket_display_status' do
    it "should return 'pending' if bucket is pending" do
      helper.bucket_display_status(mock('bucket', :status => 20)).should == 'pending'
    end

    it "should return 'in work' if bucket is in work" do
      helper.bucket_display_status(mock('bucket', :status => 30)).should == 'in work'
    end

    it "should return 'done' if bucket was successfully done" do
      helper.bucket_display_status(mock('bucket', :status => 10)).should == 'done'
    end

    it "should return 'processing failed' if bucket processing has failed" do
      helper.bucket_display_status(mock('bucket', :status => 35)).should == 'processing failed'
    end

    it "should return 'failed' if bucket has failed" do
      helper.bucket_display_status(mock('bucket', :status => 40)).should == 'failed'
    end
  end

  describe 'build_display_status' do
    before do
      @build = Build.new
    end

    it "should return 'pending' if build is pending" do
      helper.stub!(:build_status).with(@build).and_return 20
      helper.build_display_status(@build).should == 'pending'
    end

    it "should return 'in work' if build is in work" do
      helper.stub!(:build_status).with(@build).and_return 30
      helper.build_display_status(@build).should == 'in work'
    end

    it "should return 'done' if build was successfully done" do
      helper.stub!(:build_status).with(@build).and_return 10
      helper.build_display_status(@build).should == 'done'
    end

    it "should return 'processing failed' if build processing has failed" do
      helper.stub!(:build_status).with(@build).and_return 35
      helper.build_display_status(@build).should == 'processing failed'
    end

    it "should return 'failed' if build has failed" do
      helper.stub!(:build_status).with(@build).and_return 40
      helper.build_display_status(@build).should == 'failed'
    end
  end

  describe 'build_status' do
    before do
      @succeeded_bucket = mock('bucket', :status => 10)
      @pending_bucket = mock('bucket', :status => 20)
      @inwork_bucket = mock('bucket', :status => 30)
      @processing_failed_bucket = mock('bucket', :status => 35)
      @failed_bucket = mock('bucket', :status => 40)
      @build = Build.new
    end

    it "should return pending if no bucket failed or is in work and at least one is pending" do
      @build.stub!(:buckets => [@succeeded_bucket, @pending_bucket, @succeeded_bucket])
      helper.build_status(@build).should == 20
    end

    it "should return in work if no bucket failed and at least one is in work" do
      @build.stub!(:buckets =>
          [@succeeded_bucket, @pending_bucket, @inwork_bucket, @succeeded_bucket])
      helper.build_status(@build).should == 30
    end

    it "should return processing failed if no bucket failed and at least one's processing failed" do
      @build.stub!(:buckets => [@succeeded_bucket, @pending_bucket, @inwork_bucket,
          @processing_failed_bucket, @succeeded_bucket])
      helper.build_status(@build).should == 35
    end

    it "should return done iff all buckets are done" do
      @build.stub!(:buckets => [@succeeded_bucket, @succeeded_bucket])
      helper.build_status(@build).should == 10
    end

    it "should return failed if at least one bucket failed" do
      @build.stub!(:buckets => [@succeeded_bucket, @failed_bucket, @pending_bucket, @inwork_bucket,
          @processing_failed_bucket])
      helper.build_status(@build).should == 40
    end
  end

  describe 'project_display_value' do
    before do
      @project = mock('project', :name => 'project name', :url => 'project url',
          :branch => 'project branch')
    end

    it "should return the name as display value containing the url and the branch as tooltip" do
      helper.project_display_value(@project).should ==
          "<span title='URL: project url; Branch: project branch'>project name</span>"
    end
  end

  describe 'build_display_value' do
    before do
      @build = mock('build', :identifier => 'build_identifier', :leader_uri => 'leader_uri')
    end

    it "should return the display value containing the short identifier and the full identifier and the leader_uri as tooltips" do
      helper.build_display_value(@build).should ==
          "<span title='build_identifier verwaltet von leader_uri'>build_id</span>"
    end
  end

  describe 'bucket_display_value' do
    before do
      @bucket = mock('bucket', :name => 'bucket_name', :worker_uri => 'worker_uri')
    end

    it "should return the display value containing the name" do
      helper.bucket_display_value(@bucket).should =~ /bucket_name/
    end

    it "should return the worker_uri as tooltip" do
      helper.bucket_display_value(@bucket).should =~ /title='auf worker_uri'/
    end
  end

  describe 'status_css_class' do
    it "should return 'success' if the status is done" do
      helper.status_css_class(10).should == "success"
    end

    it "should return 'failure' if the status is failed or processing failed" do
      helper.status_css_class(35).should == "failure"
      helper.status_css_class(40).should == "failure"
    end

    it "should return 'pending' if the status is pending" do
      helper.status_css_class(20).should == "pending"
    end

    it "should return 'processing' if the status is in work" do
      helper.status_css_class(30).should == "processing"
    end
  end
end
