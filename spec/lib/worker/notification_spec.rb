# encoding: utf-8
require 'spec_helper'

module DCC

  describe Worker, "Notifications" do
    fixtures :buckets, :builds

    let(:bucket) {
      double('bucket',
        :logs => [],
        :name => 'task',
        :log= => nil,
        :status= => nil,
        :finished_at= => nil,
        :save => nil,
        :error_log => nil,
        :error_log= => nil,
        :build => double('build',
          :id => 1000,
          :commit => 'commit',
          :project => double('project',
            :bucket_tasks => [],
            :id => 33,
            :before_all_tasks => [],
            :before_bucket_tasks => [],
            :after_bucket_tasks => [],
            :before_all_code => nil,
            :before_each_bucket_group_code => nil,
            :bucket_group => 'default',
            :last_build => nil,
            :ruby_version => nil,
            :git => double('git', :update => nil, :path => '/nix', :current_commit => nil)
          )
        )
      )
    }

    let(:worker) {
      Worker.new('dcc_test', nil, :log_level => ::Logger::ERROR).tap { |w| w.stub(:execute) }
    }

    describe "when build failed" do
      before do
        bucket.build.project.stub(:bucket_tasks).with('task').and_return(['task'])
        worker.stub(:perform_rake_task).and_return false
        Mailer.stub(:failure_message).and_return double(deliver: nil)
        bucket.stub(:build_error_log)
      end

      it "should send an email if build failed" do
        Mailer.should_receive(:failure_message).with(bucket).
            and_return(message = double)
        message.should_receive(:deliver)
        worker.perform_task(bucket)
      end

      it "should build the error log" do
        # build_error_log braucht sowohl log als auch finished_at
        bucket.should_receive(:log=).ordered
        bucket.should_receive(:finished_at=).ordered
        bucket.should_receive(:build_error_log).ordered
        worker.perform_task(bucket)
      end
    end

    it "should send no email if build succeeded again" do
      bucket.build.project.should_receive(:last_build).with(:before_build => bucket.build).
          and_return Build.find(330)
      Mailer.should_not_receive(:failure_message)
      Mailer.should_not_receive(:fixed_message)
      worker.perform_task(bucket)
    end

    it "should send no email if first build ever succeeded" do
      bucket.build.project.should_receive(:last_build).with(:before_build => bucket.build).
          and_return nil
      Mailer.should_not_receive(:failure_message)
      Mailer.should_not_receive(:fixed_message)
      worker.perform_task(bucket)
    end

    it "should send an email if build was fixed" do
      bucket.build.project.should_receive(:last_build).with(:before_build => bucket.build).
          and_return Build.find(332)
      Mailer.should_receive(:fixed_message).with(bucket).and_return(message = double)
      message.should_receive(:deliver)
      worker.perform_task(bucket)
    end
  end

end
