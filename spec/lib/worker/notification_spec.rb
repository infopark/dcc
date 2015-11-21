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
      allow(build).to receive(:project).and_return(double('project',
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
      }).tap { |w| allow(w).to receive(:execute) }
    }

    it 'configures the hipchat_room correctly' do
      client = double(HipChat::Client)
      room = double(HipChat::Room)

      expect(HipChat::Client).to receive(:new).with(
          'cooler_hipchat_token', api_version: 'v1').and_return(client)
      expect(client).to receive(:[]).with('cooler_hipchat_room').and_return(room)

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
        allow(bucket.build.project).to receive(:bucket_tasks).with('my_bucket').and_return(['my_bucket'])
        allow(worker).to receive(:perform_rake_task).and_return false
        allow(Mailer).to receive(:failure_message).and_return double(deliver: nil)
        allow(bucket).to receive(:build_error_log)
      end

      it "should send an email if build failed" do
        expect(Mailer).to receive(:failure_message).with(bucket).
            and_return(message = double)
        expect(message).to receive(:deliver)
        worker.perform_task(bucket)
      end

      it "should build the error log" do
        # build_error_log braucht sowohl log als auch finished_at
        expect(bucket).to receive(:log=).ordered
        expect(bucket).to receive(:finished_at=).ordered
        expect(bucket).to receive(:build_error_log).ordered
        worker.perform_task(bucket)
      end

      it 'sends a hipchat message to a global channel' do
        expect(worker.hipchat_room).to receive(:send) do |user, message, options|
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
          expect(worker).to receive(:hipchat_user).with(bucket.build.project).and_return(
              '<output_of_hipchat_user>')
        end

        it 'names the hipchat user in the massage' do
          expect(worker.hipchat_room).to receive(:send) do |user, message, options|
            expect(message).to match /show_bucket\/1234<output_of_hipchat_user>/
          end

          worker.perform_task(bucket)
        end
      end
    end

    context 'when build succeeded again' do
      before do
        expect(bucket.build.project).to receive(:last_build).with(before_build: bucket.build).
            and_return Build.find(330)
      end

      it "sends no email" do
        expect(Mailer).not_to receive(:failure_message)
        expect(Mailer).not_to receive(:fixed_message)
        worker.perform_task(bucket)
      end

      it "sends no hipchat message" do
        expect(worker.hipchat_room).not_to receive(:send)
        worker.perform_task(bucket)
      end
    end

    context 'when first build ever succeeded' do
      before do
        expect(bucket.build.project).to receive(:last_build).with(before_build: bucket.build).
            and_return nil
      end

      it "sends no email" do
        expect(Mailer).not_to receive(:failure_message)
        expect(Mailer).not_to receive(:fixed_message)
        worker.perform_task(bucket)
      end

      it "sends no hipchat message" do
        expect(worker.hipchat_room).not_to receive(:send)
        worker.perform_task(bucket)
      end
    end

    context 'when build was fixed' do
      before do
        buckets = double
        expect(buckets).to receive(:find_by_name).with('my_bucket').and_return(double(status: 40))
        last_build = double(buckets: buckets)

        expect(bucket.build.project).to receive(:last_build).with(before_build: bucket.build).
            and_return last_build

        allow(Mailer).to receive(:fixed_message).and_return double(deliver: nil)
      end

      it "should send an email if build was fixed" do
        message = double
        expect(Mailer).to receive(:fixed_message).with(bucket).and_return(message)
        expect(message).to receive(:deliver)
        worker.perform_task(bucket)
      end

      it 'sends a hipchat message to a global channel' do
        expect(worker.hipchat_room).to receive(:send) do |user, message, options|
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
