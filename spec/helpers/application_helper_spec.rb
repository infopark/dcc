# encoding: utf-8
require File.dirname(__FILE__) + '/../spec_helper'

describe ApplicationHelper do
  describe 'bucket_display_status' do
    before do
      @bucket = double('bucket', :started_at => nil, :finished_at => nil, :status => 10)
    end

    it "should return 'pending' if bucket is pending" do
      allow(@bucket).to receive(:status).and_return 20
      expect(helper.bucket_display_status(@bucket)).to eq('pending')
    end

    it "should return 'in work' if bucket is in work" do
      allow(@bucket).to receive(:status).and_return 30
      expect(helper.bucket_display_status(@bucket)).to eq('in work')
    end

    it "should return 'done' if bucket was successfully done" do
      allow(@bucket).to receive(:status).and_return 10
      expect(helper.bucket_display_status(@bucket)).to eq('done')
    end

    it "should return 'processing failed' if bucket processing has failed" do
      allow(@bucket).to receive(:status).and_return 35
      expect(helper.bucket_display_status(@bucket)).to eq('processing failed')
    end

    it "should return 'failed' if bucket has failed" do
      allow(@bucket).to receive(:status).and_return 40
      expect(helper.bucket_display_status(@bucket)).to eq('failed')
    end

    it "should contain 'since …' if the bucket is in progress" do
      now = Time.now
      allow(@bucket).to receive(:started_at).and_return now
      expect(helper.bucket_display_status(@bucket)).to match(/since #{now.to_formatted_s(:db)}/)
    end

    it "should contain 'in …' if the bucket is finished" do
      start = Time.now
      finish = start + 6666
      allow(@bucket).to receive(:started_at).and_return start
      allow(@bucket).to receive(:finished_at).and_return finish
      expect(helper.bucket_display_status(@bucket)).to match(/in 1 hour 51 minutes 6 seconds/)

      finish = start + 36061
      allow(@bucket).to receive(:finished_at).and_return finish
      expect(helper.bucket_display_status(@bucket)).to match(/in 10 hours 1 minute 1 second/)

      finish = start + 3600
      allow(@bucket).to receive(:finished_at).and_return finish
      expect(helper.bucket_display_status(@bucket)).to match(/in 1 hour/)

      finish = start + 3606
      allow(@bucket).to receive(:finished_at).and_return finish
      expect(helper.bucket_display_status(@bucket)).to match(/in 1 hour 6 seconds/)

      finish = start + 120
      allow(@bucket).to receive(:finished_at).and_return finish
      expect(helper.bucket_display_status(@bucket)).to match(/in 2 minutes/)

      finish = start + 12
      allow(@bucket).to receive(:finished_at).and_return finish
      expect(helper.bucket_display_status(@bucket)).to match(/in 12 seconds/)
    end
  end

  describe 'build_display_status' do
    before do
      @build = Build.new
      allow(helper).to receive(:build_status).with(@build).and_return 10
      allow(helper).to receive(:detailed_build_status).with(@build).and_return({})
    end

    it "should return 'pending' if build is pending" do
      allow(helper).to receive(:build_status).with(@build).and_return 20
      expect(helper.build_display_status(@build)).to match(/^pending/)
    end

    it "should return 'in work' if build is in work" do
      allow(helper).to receive(:build_status).with(@build).and_return 30
      expect(helper.build_display_status(@build)).to match(/^in work/)
    end

    it "should return 'done' if build was successfully done" do
      allow(helper).to receive(:build_status).with(@build).and_return 10
      expect(helper.build_display_status(@build)).to match(/^done/)
    end

    it "should return 'processing failed' if build processing has failed" do
      allow(helper).to receive(:build_status).with(@build).and_return 35
      expect(helper.build_display_status(@build)).to match(/^processing failed/)
    end

    it "should return 'failed' if build has failed" do
      allow(helper).to receive(:build_status).with(@build).and_return 40
      expect(helper.build_display_status(@build)).to match(/^failed/)
    end

    it "should contain summary information on bucket states" do
      allow(helper).to receive(:detailed_build_status).with(@build).and_return({
        10 => 3,
        20 => 5,
        30 => 2,
        35 => 7,
        40 => 1
      })
      expect(helper.build_display_status(@build)).to match(
          /\(3 done, 5 pending, 2 in work, 7 processing failed, 1 failed\)/
      )
    end

    it "should contain no summary information on states where no bucket is in" do
      allow(helper).to receive(:detailed_build_status).with(@build).and_return({
        10 => 0,
        20 => 5,
        35 => 7
      })
      expect(helper.build_display_status(@build)).to match(/\(5 pending, 7 processing failed\)/)
    end

    it "should contain 'since …' if the build is in progress" do
      now = Time.now
      allow(@build).to receive(:started_at).and_return now
      expect(helper.build_display_status(@build)).to match(/since #{now.to_formatted_s(:db)}/)
    end

    it "should contain 'in …' if the build is finished" do
      start = Time.now
      finish = start + 6666
      allow(@build).to receive(:started_at).and_return start
      allow(@build).to receive(:finished_at).and_return finish
      expect(helper.build_display_status(@build)).to match(/in 1 hour 51 minutes 6 seconds/)

      finish = start + 36061
      allow(@build).to receive(:finished_at).and_return finish
      expect(helper.build_display_status(@build)).to match(/in 10 hours 1 minute 1 second/)

      finish = start + 3600
      allow(@build).to receive(:finished_at).and_return finish
      expect(helper.build_display_status(@build)).to match(/in 1 hour/)

      finish = start + 3606
      allow(@build).to receive(:finished_at).and_return finish
      expect(helper.build_display_status(@build)).to match(/in 1 hour 6 seconds/)

      finish = start + 120
      allow(@build).to receive(:finished_at).and_return finish
      expect(helper.build_display_status(@build)).to match(/in 2 minutes/)

      finish = start + 12
      allow(@build).to receive(:finished_at).and_return finish
      expect(helper.build_display_status(@build)).to match(/in 12 seconds/)
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
      allow(@build).to receive_messages(:buckets => [@succeeded_bucket, @pending_bucket, @succeeded_bucket])
      expect(helper.build_status(@build)).to eq(20)
    end

    it "should return in work if no bucket failed and at least one is in work" do
      allow(@build).to receive_messages(:buckets =>
          [@succeeded_bucket, @pending_bucket, @inwork_bucket, @succeeded_bucket])
      expect(helper.build_status(@build)).to eq(30)
    end

    it "should return processing failed if no bucket failed and at least one's processing failed" do
      allow(@build).to receive_messages(:buckets => [@succeeded_bucket, @pending_bucket, @inwork_bucket,
          @processing_failed_bucket, @succeeded_bucket])
      expect(helper.build_status(@build)).to eq(35)
    end

    it "should return done iff all buckets are done" do
      allow(@build).to receive_messages(:buckets => [@succeeded_bucket, @succeeded_bucket])
      expect(helper.build_status(@build)).to eq(10)
    end

    it "should return failed if at least one bucket failed" do
      allow(@build).to receive_messages(:buckets => [@succeeded_bucket, @failed_bucket, @pending_bucket, @inwork_bucket,
          @processing_failed_bucket])
      expect(helper.build_status(@build)).to eq(40)
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
      allow(@build).to receive_messages(:buckets =>
          [@succeeded_bucket, @pending_bucket, @succeeded_bucket, @pending_bucket])
      expect(helper.detailed_build_status(@build)).to eq({10 => 2, 20 => 2})
      allow(@build).to receive_messages(:buckets => [@succeeded_bucket, @pending_bucket, @inwork_bucket,
          @processing_failed_bucket, @failed_bucket])
      expect(helper.detailed_build_status(@build)).to eq({10 => 1, 20 => 1, 30 => 1, 35 => 1, 40 => 1})
    end
  end

  describe 'build_gitweb_url' do
    before do
      @project = double('project', :url => '')
      @build = double('build', identifier: 'build_identifier', leader_uri: 'leader_uri',
          leader_hostname: 'leader_hostname', project: @project, commit: 'commit_hash')
      allow(YAML).to receive(:load_file).with("#{Rails.root}/config/gitweb_url_map.yml").and_return({
            '^git@machine:(.*?)(\.git)?$' => 'gitweb_url1 #{$1} #{commit}',
            '^git+ssh://machine/(.*?)(\.git)?$' => 'gitweb_url2 #{$1} #{commit}',
            '^git://github.com/(.*?)(\.git)?$' => 'gitweb_url3 #{$1} #{commit}'
          })
    end

    it "should return the gitweb url for the project" do
      allow(@project).to receive(:url).and_return "git@machine:the_project.git"
      expect(helper.build_gitweb_url(@build)).to eq('gitweb_url1 the_project commit_hash')

      allow(@project).to receive(:url).and_return "git@machine:the_project"
      expect(helper.build_gitweb_url(@build)).to eq('gitweb_url1 the_project commit_hash')

      allow(@project).to receive(:url).and_return "git://github.com/my/project.git"
      expect(helper.build_gitweb_url(@build)).to eq('gitweb_url3 my/project commit_hash')

      allow(@project).to receive(:url).and_return "git://github.com/my/project"
      expect(helper.build_gitweb_url(@build)).to eq('gitweb_url3 my/project commit_hash')
    end

    it "should return nil if no gitweb url is configured" do
      allow(@project).to receive(:url).and_return "nix configured"
      expect(helper.build_gitweb_url(@build)).to be_nil
    end
  end

  describe 'build_display_identifier' do
    before do
      @build = Build.new
    end

    it "should return a short version of the build identifier" do
      allow(@build).to receive(:identifier).and_return("ziemlich lang datt ding")
      expect(helper.build_display_identifier(@build)).to eq("ziemlich")

      allow(@build).to receive(:identifier).and_return("kurz!")
      expect(helper.build_display_identifier(@build)).to eq("kurz!")
    end

    it "should preserve the build number in the identifier" do
      allow(@build).to receive(:identifier).and_return("ziemlich lang datt ding.build number")
      expect(helper.build_display_identifier(@build)).to eq("ziemlich.build number")
    end
  end

  describe 'build_display_details' do
    before do
      @build = double('build', identifier: "ziemlich lang das ding", leader_uri: "leader's uri",
          leader_hostname: "leader's hostname")
    end

    it "should return info containing the full identifier and the leader hostname" do
      expect(helper.build_display_details(@build)).to match(/ziemlich lang das ding/)
      expect(helper.build_display_details(@build)).to match(/leader's hostname/)
    end
  end

  describe 'bucket_display_details' do
    before do
      @bucket = double('bucket', name: 'bucket_name', worker_uri: 'worker_uri',
          worker_hostname: 'worker_hostname')
    end

    it "should return info containing the worker hostname" do
      expect(helper.bucket_display_details(@bucket)).to match(/worker_hostname/)
    end
  end

  describe 'status_css_class' do
    it "should return 'success' if the status is done" do
      expect(helper.status_css_class(10)).to eq("success")
    end

    it "should return 'failure' if the status is failed or processing failed" do
      expect(helper.status_css_class(35)).to eq("failure")
      expect(helper.status_css_class(40)).to eq("failure")
    end

    it "should return 'in_progress' if the status is pending or in work" do
      expect(helper.status_css_class(20)).to eq("in_progress")
      expect(helper.status_css_class(30)).to eq("in_progress")
    end
  end

  describe 'bucket_failed?' do
    before do
      @bucket = double('bucket')
    end

    it "should return 'true' if the bucket or the processing for it failed" do
      allow(@bucket).to receive(:status).and_return(35)
      expect(helper.bucket_failed?(@bucket)).to be_truthy
      allow(@bucket).to receive(:status).and_return(40)
      expect(helper.bucket_failed?(@bucket)).to be_truthy
    end

    it "should return 'false' otherwise" do
      allow(@bucket).to receive(:status).and_return(10)
      expect(helper.bucket_failed?(@bucket)).to be_falsey
      allow(@bucket).to receive(:status).and_return(20)
      expect(helper.bucket_failed?(@bucket)).to be_falsey
      allow(@bucket).to receive(:status).and_return(30)
      expect(helper.bucket_failed?(@bucket)).to be_falsey
    end
  end
end
