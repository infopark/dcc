# encoding: utf-8
require File.dirname(__FILE__) + '/../spec_helper'

describe ApplicationHelper do
  describe 'bucket_display_status' do
    before do
      @bucket = double('bucket', :started_at => nil, :finished_at => nil, :status => 10)
    end

    it "should return 'pending' if bucket is pending" do
      @bucket.stub(:status).and_return 20
      helper.bucket_display_status(@bucket).should == 'pending'
    end

    it "should return 'in work' if bucket is in work" do
      @bucket.stub(:status).and_return 30
      helper.bucket_display_status(@bucket).should == 'in work'
    end

    it "should return 'done' if bucket was successfully done" do
      @bucket.stub(:status).and_return 10
      helper.bucket_display_status(@bucket).should == 'done'
    end

    it "should return 'processing failed' if bucket processing has failed" do
      @bucket.stub(:status).and_return 35
      helper.bucket_display_status(@bucket).should == 'processing failed'
    end

    it "should return 'failed' if bucket has failed" do
      @bucket.stub(:status).and_return 40
      helper.bucket_display_status(@bucket).should == 'failed'
    end

    it "should contain 'since …' if the bucket is in progress" do
      now = Time.now
      @bucket.stub(:started_at).and_return now
      helper.bucket_display_status(@bucket).should =~ /since #{now.to_formatted_s(:db)}/
    end

    it "should contain 'in …' if the bucket is finished" do
      start = Time.now
      finish = start + 6666
      @bucket.stub(:started_at).and_return start
      @bucket.stub(:finished_at).and_return finish
      helper.bucket_display_status(@bucket).should =~ /in 1 hour 51 minutes 6 seconds/

      finish = start + 36061
      @bucket.stub(:finished_at).and_return finish
      helper.bucket_display_status(@bucket).should =~ /in 10 hours 1 minute 1 second/

      finish = start + 3600
      @bucket.stub(:finished_at).and_return finish
      helper.bucket_display_status(@bucket).should =~ /in 1 hour/

      finish = start + 3606
      @bucket.stub(:finished_at).and_return finish
      helper.bucket_display_status(@bucket).should =~ /in 1 hour 6 seconds/

      finish = start + 120
      @bucket.stub(:finished_at).and_return finish
      helper.bucket_display_status(@bucket).should =~ /in 2 minutes/

      finish = start + 12
      @bucket.stub(:finished_at).and_return finish
      helper.bucket_display_status(@bucket).should =~ /in 12 seconds/
    end
  end

  describe 'build_display_status' do
    before do
      @build = Build.new
      helper.stub(:build_status).with(@build).and_return 10
      helper.stub(:detailed_build_status).with(@build).and_return({})
    end

    it "should return 'pending' if build is pending" do
      helper.stub(:build_status).with(@build).and_return 20
      helper.build_display_status(@build).should =~ /^pending/
    end

    it "should return 'in work' if build is in work" do
      helper.stub(:build_status).with(@build).and_return 30
      helper.build_display_status(@build).should =~ /^in work/
    end

    it "should return 'done' if build was successfully done" do
      helper.stub(:build_status).with(@build).and_return 10
      helper.build_display_status(@build).should =~ /^done/
    end

    it "should return 'processing failed' if build processing has failed" do
      helper.stub(:build_status).with(@build).and_return 35
      helper.build_display_status(@build).should =~ /^processing failed/
    end

    it "should return 'failed' if build has failed" do
      helper.stub(:build_status).with(@build).and_return 40
      helper.build_display_status(@build).should =~ /^failed/
    end

    it "should contain summary information on bucket states" do
      helper.stub(:detailed_build_status).with(@build).and_return({
        10 => 3,
        20 => 5,
        30 => 2,
        35 => 7,
        40 => 1
      })
      helper.build_display_status(@build).should =~
          /\(3 done, 5 pending, 2 in work, 7 processing failed, 1 failed\)/
    end

    it "should contain no summary information on states where no bucket is in" do
      helper.stub(:detailed_build_status).with(@build).and_return({
        10 => 0,
        20 => 5,
        35 => 7
      })
      helper.build_display_status(@build).should =~ /\(5 pending, 7 processing failed\)/
    end

    it "should contain 'since …' if the build is in progress" do
      now = Time.now
      @build.stub(:started_at).and_return now
      helper.build_display_status(@build).should =~ /since #{now.to_formatted_s(:db)}/
    end

    it "should contain 'in …' if the build is finished" do
      start = Time.now
      finish = start + 6666
      @build.stub(:started_at).and_return start
      @build.stub(:finished_at).and_return finish
      helper.build_display_status(@build).should =~ /in 1 hour 51 minutes 6 seconds/

      finish = start + 36061
      @build.stub(:finished_at).and_return finish
      helper.build_display_status(@build).should =~ /in 10 hours 1 minute 1 second/

      finish = start + 3600
      @build.stub(:finished_at).and_return finish
      helper.build_display_status(@build).should =~ /in 1 hour/

      finish = start + 3606
      @build.stub(:finished_at).and_return finish
      helper.build_display_status(@build).should =~ /in 1 hour 6 seconds/

      finish = start + 120
      @build.stub(:finished_at).and_return finish
      helper.build_display_status(@build).should =~ /in 2 minutes/

      finish = start + 12
      @build.stub(:finished_at).and_return finish
      helper.build_display_status(@build).should =~ /in 12 seconds/
    end
  end

  describe 'build_status' do
    before do
      @succeeded_bucket = double('bucket', :status => 10)
      @pending_bucket = double('bucket', :status => 20)
      @inwork_bucket = double('bucket', :status => 30)
      @processing_failed_bucket = double('bucket', :status => 35)
      @failed_bucket = double('bucket', :status => 40)
      @build = Build.new
    end

    it "should return pending if no bucket failed or is in work and at least one is pending" do
      @build.stub(:buckets => [@succeeded_bucket, @pending_bucket, @succeeded_bucket])
      helper.build_status(@build).should == 20
    end

    it "should return in work if no bucket failed and at least one is in work" do
      @build.stub(:buckets =>
          [@succeeded_bucket, @pending_bucket, @inwork_bucket, @succeeded_bucket])
      helper.build_status(@build).should == 30
    end

    it "should return processing failed if no bucket failed and at least one's processing failed" do
      @build.stub(:buckets => [@succeeded_bucket, @pending_bucket, @inwork_bucket,
          @processing_failed_bucket, @succeeded_bucket])
      helper.build_status(@build).should == 35
    end

    it "should return done iff all buckets are done" do
      @build.stub(:buckets => [@succeeded_bucket, @succeeded_bucket])
      helper.build_status(@build).should == 10
    end

    it "should return failed if at least one bucket failed" do
      @build.stub(:buckets => [@succeeded_bucket, @failed_bucket, @pending_bucket, @inwork_bucket,
          @processing_failed_bucket])
      helper.build_status(@build).should == 40
    end
  end

  describe 'detailed_build_status' do
    before do
      @succeeded_bucket = double('bucket', :status => 10)
      @pending_bucket = double('bucket', :status => 20)
      @inwork_bucket = double('bucket', :status => 30)
      @processing_failed_bucket = double('bucket', :status => 35)
      @failed_bucket = double('bucket', :status => 40)
      @build = Build.new
    end

    it "should return summary information on bucket states" do
      @build.stub(:buckets =>
          [@succeeded_bucket, @pending_bucket, @succeeded_bucket, @pending_bucket])
      helper.detailed_build_status(@build).should == {10 => 2, 20 => 2}
      @build.stub(:buckets => [@succeeded_bucket, @pending_bucket, @inwork_bucket,
          @processing_failed_bucket, @failed_bucket])
      helper.detailed_build_status(@build).should == {10 => 1, 20 => 1, 30 => 1, 35 => 1, 40 => 1}
    end
  end

  describe 'build_gitweb_url' do
    before do
      @project = double('project', :url => '')
      @build = double('build', :identifier => 'build_identifier', :leader_uri => 'leader_uri',
          :project => @project, :commit => 'commit_hash')
      YAML.stub(:load_file).with("#{Rails.root}/config/gitweb_url_map.yml").and_return({
            '^git@machine:(.*?)(\.git)?$' => 'gitweb_url1 #{$1} #{commit}',
            '^git+ssh://machine/(.*?)(\.git)?$' => 'gitweb_url2 #{$1} #{commit}',
            '^git://github.com/(.*?)(\.git)?$' => 'gitweb_url3 #{$1} #{commit}'
          })
    end

    it "should return the gitweb url for the project" do
      @project.stub(:url).and_return "git@machine:the_project.git"
      helper.build_gitweb_url(@build).should == 'gitweb_url1 the_project commit_hash'

      @project.stub(:url).and_return "git@machine:the_project"
      helper.build_gitweb_url(@build).should == 'gitweb_url1 the_project commit_hash'

      @project.stub(:url).and_return "git://github.com/my/project.git"
      helper.build_gitweb_url(@build).should == 'gitweb_url3 my/project commit_hash'

      @project.stub(:url).and_return "git://github.com/my/project"
      helper.build_gitweb_url(@build).should == 'gitweb_url3 my/project commit_hash'
    end

    it "should return nil if no gitweb url is configured" do
      @project.stub(:url).and_return "nix configured"
      helper.build_gitweb_url(@build).should be_nil
    end
  end

  describe 'build_display_identifier' do
    before do
      @build = Build.new
    end

    it "should return a short version of the build identifier" do
      @build.stub(:identifier).and_return("ziemlich lang datt ding")
      helper.build_display_identifier(@build).should == "ziemlich"

      @build.stub(:identifier).and_return("kurz!")
      helper.build_display_identifier(@build).should == "kurz!"
    end

    it "should preserve the build number in the identifier" do
      @build.stub(:identifier).and_return("ziemlich lang datt ding.build number")
      helper.build_display_identifier(@build).should == "ziemlich.build number"
    end
  end

  describe 'build_display_details' do
    before do
      @build = double('build', :identifier => "ziemlich lang das ding", :leader_uri => "leader's uri")
    end

    it "should return info containing the full identifier and the leader uri" do
      helper.build_display_details(@build).should =~ /ziemlich lang das ding/
      helper.build_display_details(@build).should =~ /leader's uri/
    end
  end

  describe 'bucket_display_details' do
    before do
      @bucket = double('bucket', :name => 'bucket_name', :worker_uri => 'worker_uri')
    end

    it "should return info containing the worker uri" do
      helper.bucket_display_details(@bucket).should =~ /worker_uri/
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

    it "should return 'in_progress' if the status is pending or in work" do
      helper.status_css_class(20).should == "in_progress"
      helper.status_css_class(30).should == "in_progress"
    end
  end

  describe 'bucket_failed?' do
    before do
      @bucket = double('bucket')
    end

    it "should return 'true' if the bucket or the processing for it failed" do
      @bucket.stub(:status).and_return(35)
      helper.bucket_failed?(@bucket).should be_true
      @bucket.stub(:status).and_return(40)
      helper.bucket_failed?(@bucket).should be_true
    end

    it "should return 'false' otherwise" do
      @bucket.stub(:status).and_return(10)
      helper.bucket_failed?(@bucket).should be_false
      @bucket.stub(:status).and_return(20)
      helper.bucket_failed?(@bucket).should be_false
      @bucket.stub(:status).and_return(30)
      helper.bucket_failed?(@bucket).should be_false
    end
  end
end
