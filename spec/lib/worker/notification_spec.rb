# encoding: utf-8
require 'spec_helper'

module DCC

  describe Worker, "Notifications" do
    fixtures :buckets, :builds

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
        git: double('git', update: nil, path: '/nix', current_commit: nil),
        github_user: 'foobar user'
      ))

      double('bucket',
        :id => 1234,
        :logs => [],
        :name => 'my_bucket',
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
        log_level: ::Logger::ERROR,
        gui_base_url: 'xy://somewhere',
        hipchat: {
          token: 'cooler_hipchat_token',
          room: 'cooler_hipchat_room',
          user_mapping: {
            "github_x" => :random123,
            "github_y" => :hipchat_y
          }
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

    describe 'worker#hipchat_user' do
      it 'returns nil, when github user is not known' do
        project = double(github_user: 'random_unknown_user')

        expect(worker.hipchat_user(project)).to be nil
      end

      it 'returns the hipchat user, when github user is known' do
        project = double(github_user: 'github_x')

        expect(worker.hipchat_user(project)).to eq ' /cc @random123'
      end
    end

    describe "when build failed" do
      before do
        bucket.build.project.stub(:bucket_tasks).with('my_bucket').and_return(['my_bucket'])
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
          expect(message).to eq '[My Project] my_bucket failed - ' +
              'xy://somewhere/project/show_bucket/1234'
          expect(options[:color]).to eq 'red'
          expect(options[:notify]).to be
          expect(options[:message_format]).to eq 'text'
        end

        worker.perform_task(bucket)
      end

      context 'when a hipchat user is configured' do
        before do
          worker.should_receive(:hipchat_user).with(bucket.build.project).and_return(
              '<output_of_hipchat_user>')
        end

        it 'names the hipchat user in the massage' do
          worker.hipchat_room.should_receive(:send) do |user, message, options|
            expect(message).to match /show_bucket\/1234<output_of_hipchat_user>/
          end

          worker.perform_task(bucket)
        end
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

      it "sends no hipchat message" do
        worker.hipchat_room.should_not_receive(:send)
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

      it "sends no hipchat message" do
        worker.hipchat_room.should_not_receive(:send)
        worker.perform_task(bucket)
      end
    end

    context 'when build was fixed' do
      before do
        buckets = double
        buckets.should_receive(:find_by_name).with('my_bucket').and_return(double(status: 40))
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
          expect(message).to eq '[My Project] my_bucket repaired - ' +
              'xy://somewhere/project/show_bucket/1234'
          expect(options[:color]).to eq 'green'
          expect(options[:notify]).to be
          expect(options[:message_format]).to eq 'text'
        end

        worker.perform_task(bucket)
      end
    end
  end

end
