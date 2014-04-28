# encoding: utf-8
require 'spec_helper'

module DCC

  describe Worker, "Notifications" do
    let(:bucket) {
      build = Build.new()
      build.id = 1000
      build.commit = 'very long commit hash'
      build.build_number = 2342
      build.stub(:project).and_return(double('project',
        name: 'My Project',
        bucket_tasks: [],
        id: 33,
        before_all_tasks: [],
        before_bucket_tasks: [],
        after_bucket_tasks: [],
        before_all_code: nil,
        before_each_bucket_group_code: nil,
        bucket_group: 'default',
        last_build: nil,
        ruby_version: nil,
        git: double('git', update: nil, path: '/nix', current_commit: nil)
      ))

      double('bucket',
        :logs => [],
        :name => 'my bucket',
        :log= => nil,
        :status= => nil,
        :finished_at= => nil,
        :save => nil,
        :error_log => nil,
        :error_log= => nil,
        :build => build
      )
    }

    let(:worker) {
      Worker.new('dcc_test', nil, {
        :log_level => ::Logger::ERROR,
        hipchat: {
          token: 'cooler_hipchat_token',
          room: 'cooler_hipchat_room',
        }
      }).tap { |w| w.stub(:execute) }
    }

    it 'configures the hipchat_room correctly' do
      client = double(HipChat::Client)
      room = double(HipChat::Room)

      HipChat::Client.should_receive(:new).with(
          'cooler_hipchat_token', api_version: 'v1').and_return(client)
      client.should_receive(:[]).with('cooler_hipchat_room').and_return(room)

      expect(worker.hipchat_room).to equal(room)
    end

    describe "when build failed" do
      before do
        bucket.build.project.stub(:bucket_tasks).with('my bucket').and_return(['my bucket'])
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

      it 'sends a hipchat message to a global channel' do
        worker.hipchat_room.should_receive(:send) do |user, message, options|
          expect(user).to eq 'DCC'
          expect(message).to eq '[My Project] my bucket failed (Build: very lon.2342).'
          expect(options[:color]).to eq 'red'
          expect(options[:notify]).to be
          expect(options[:message_format]).to eq 'text'
        end

        worker.perform_task(bucket)
      end
    end

    context 'when build succeeded again' do
      before do
        bucket.build.project.should_receive(:last_build).with(:before_build => bucket.build).
            and_return Build.find(330)
      end

      it "sends no email" do
        Mailer.should_not_receive(:failure_message)
        Mailer.should_not_receive(:fixed_message)
        worker.perform_task(bucket)
      end
    end

    context 'when first build ever succeeded' do
      before do
        bucket.build.project.should_receive(:last_build).with(:before_build => bucket.build).
            and_return nil
      end

      it "sends no email" do
        Mailer.should_not_receive(:failure_message)
        Mailer.should_not_receive(:fixed_message)
        worker.perform_task(bucket)
      end
    end

    context 'when build was fixed' do
      before do
        buckets = double
        buckets.should_receive(:find_by_name).with('my bucket').and_return(double(status: 40))
        last_build = double(buckets: buckets)

        bucket.build.project.should_receive(:last_build).with(:before_build => bucket.build).
            and_return last_build

        Mailer.stub(:fixed_message).and_return double(deliver: nil)
      end

      it "should send an email if build was fixed" do
        message = double
        Mailer.should_receive(:fixed_message).with(bucket).and_return(message)
        message.should_receive(:deliver)
        worker.perform_task(bucket)
      end

      it 'sends a hipchat message to a global channel' do
        worker.hipchat_room.should_receive(:send) do |user, message, options|
          expect(user).to eq 'DCC'
          expect(message).to eq '[My Project] my bucket repaired (Build: very lon.2342).'
          expect(options[:color]).to eq 'green'
          expect(options[:notify]).to be
          expect(options[:message_format]).to eq 'text'
        end

        worker.perform_task(bucket)
      end
    end
  end

end
