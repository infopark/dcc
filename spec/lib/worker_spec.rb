# encoding: utf-8
require 'spec_helper'

require 'dcc/rake'
require 'support/worker_spec_support'

module DCC

class TestRake < Rake
  def initialize
    FileUtils.mkdir_p self.class.path
    super(self.class.path, File.join(self.class.path, "rake.log"))
  end

  def self.path
    'tmp'
  end

  def self.log_files
    @log_files ||= []
  end

  def self.cleanup
    FileUtils.rm_rf path
    log_files.each {|file| FileUtils.rm_f file }
  end

  def log_file=(log_file)
    self.class.log_files << log_file
    @log_file = log_file
  end

  def rake(*args)
    File.open(@log_file, "w:iso-8859-1") do |f|
      # angebissenes € am Ende
      f.write "first fünf rake output\n€".force_encoding('ISO8859-1')[0..-2]
      f.flush
      sleep 0.3
      # € geht weiter
      f.write "€second fünf rake output\n€".force_encoding('ISO8859-1')[2..-2]
      f.flush
      sleep 0.2
      f.write "€third fünf rake output\n€".force_encoding('ISO8859-1')[2..-3]
      f.flush
      sleep 0.2
      f.write "€last fünf rake output\n".force_encoding('ISO8859-1')[1..-1]
    end
  end
end

describe Worker do
  let(:worker) { Worker.new('dcc_test', nil, :log_level => ::Logger::ERROR) }

  describe "#bucket_request_context" do
    it "should contain the hostname" do
      allow(Socket).to receive(:gethostname).and_return "Scooby Doo"
      expect(worker.bucket_request_context[:hostname]).to eq("Scooby Doo")
    end
  end

  describe "when performing operation protected against MySQL failures" do
    it "should return the block's result if MySQL did not fail" do
      expect(worker.send(:retry_on_mysql_failure) do
        "das ergebnis"
      end).to eq("das ergebnis")
    end

    it "should return the block's result if MySQL fails once and succeeds afterwards" do
      failed = false
      expect(worker.send(:retry_on_mysql_failure) do
        unless failed
          failed = true
          raise ActiveRecord::StatementInvalid.new("MySQL server has gone away")
        end
        "das ergebnis"
      end).to eq("das ergebnis")
    end
  end
end

describe Worker, "when running as follower" do
  before do
    @worker = Worker.new('dcc_test', nil, :log_level => ::Logger::ERROR)
    leader = Worker.new('dcc_test', nil, :log_level => ::Logger::ERROR)
    allow(@worker).to receive(:leader).and_return leader
    allow(leader).to receive(:bucket_request).and_return ["b_id1", 10], ["b_id2", 10], ["b_id3", 10], [nil, 10]
    allow(@worker).to receive(:client_for).
        and_return(double(Dalli::Client, add: nil, get: leader.uri))
    allow(@worker).to receive(:loop?).and_return true, true, false
    @worker.send(:log).level = ::Logger::FATAL
    allow(Bucket).to receive(:find)
    @buckets = {}
    [1, 2, 3].each do |i|
      allow(Bucket).to receive(:find).with("b_id#{i}").and_return(@buckets[i] = mock_model(Bucket,
        name: "bucket #{i}",
        build: mock_model(Build,
          project: mock_model(Project, ruby_version: nil, bucket_group_environment: {})
        )
      ))
    end
  end

  it "should perform all tasks given from leader" do
    expect(@worker).to receive(:perform_task).with(@buckets[1])
    expect(@worker).to receive(:perform_task).with(@buckets[2])
    expect(@worker).to receive(:perform_task).with(@buckets[3])
    @worker.run
  end

  describe 'when determining if it is processing a specific bucket' do
    before do
      allow(@worker).to receive(:perform_task)
      allow(@worker).to receive(:loop?).and_return false
    end

    it "should say no if no bucket is being processed" do
      allow(@worker.leader).to receive(:bucket_request).and_return [nil, 1]
      @worker.run
      expect(@worker).not_to be_processing('b_id1')
    end

    it "should say no if another bucket is being processed" do
      allow(@worker.leader).to receive(:bucket_request).and_return ['b_id2', 1], [nil, 1]
      @worker.run
      expect(@worker).not_to be_processing('b_id1')
    end

    it "should say yes if the bucket is being processed" do
      allow(@worker.leader).to receive(:bucket_request).and_return ['b_id1', 1], [nil, 1]
      @worker.run
      expect(@worker).to be_processing('b_id1')
    end
  end

  describe 'when even the basic things (process_bucket) fail' do
    before do
      allow(@worker).to receive(:process_bucket).and_raise("an error")
    end

    it "should send an email to the admin" do
      allow(@worker).to receive(:admin_e_mail_address).and_return('admin-e-mail')
      expect(Mailer).to receive(:dcc_message).with('admin-e-mail', 'running worker failed', /an error/).
          and_return(message = double)
      expect(message).to receive(:deliver)
      @worker.run
    end
  end

  describe 'when perform_task fails' do
    let(:log_scope) { Bucket.select([:log, :error_log]) }

    let(:bucket) { double('bucket',
      :name => 'bucket',
      :id => 'some',
      :status= => nil,
      :save => nil,
      :log= => nil,
      :log => 'old_log',
      :build => double('build',
        :leader_hostname => nil,
        :project => double('project', ruby_version: nil, bucket_group_environment: {})
      )
    ) }

    before do
      allow(@worker).to receive(:loop?).and_return false
      allow(log_scope).to receive(:find).and_return bucket
      allow(Bucket).to receive(:find).and_return bucket
      allow(Bucket).to receive(:select).and_return log_scope
      allow(@worker).to receive(:perform_task).and_raise("an error")
    end

    it "should set bucket's status to 'processing failed'" do
      expect(bucket).to receive(:status=).with(35).ordered
      expect(bucket).to receive(:save).ordered
      @worker.run
    end

    it "should set the error into the database" do
      expect(bucket).to receive(:log=).with(/old_log.*processing bucket failed.*an error/m).ordered
      expect(bucket).to receive(:save).ordered
      @worker.run
    end

    it "should set the error into the database even if no log exists" do
      allow(bucket).to receive(:log).and_return nil
      expect(bucket).to receive(:log=).with(/.*processing bucket failed.*an error/m).ordered
      expect(bucket).to receive(:save).ordered
      @worker.run
    end
  end

  describe '' do
    before do
      @git = double('git', :path => 'git path', :update => nil, :current_commit => nil)
      @project = double('project', name: "project's name", before_all_tasks: [], git: @git,
          e_mail_receivers: [], before_bucket_tasks: [], after_bucket_tasks: [], id: 1,
          last_build: nil, ruby_version: nil, github_user: 'foobar', bucket_group_environment: {})
      allow(@project).to receive(:bucket_tasks).with('t1').and_return(['rt1'])
      allow(@project).to receive(:bucket_tasks).with('t2').and_return(['rt21', 'rt22'])
      @logs = [double('l1', :log => 'log1'), double('l2', :log => 'log2')]
      @bucket = double('bucket',
        :id => 2342,
        :name => "t2",
        :log= => nil,
        :finished_at= => nil,
        :error_log= => nil,
        :error_log => nil,
        :save => nil,
        :logs => @logs,
        :status= => nil,
        :log => "nothing to say here",
        :build_error_log => nil,
        :build => double('build',
          :id => 123,
          :identifier => 'the commit.666',
          :project => @project,
          :commit => 'the commit',
          :build_number => 666,
          :short_identifier => 'very sho'
        ),
      )
    end

    describe "the environment of the task execution" do
      before do
        allow(@worker).to receive(:perform_task) { @perform_task_env = ENV.to_hash }
        allow(Bucket).to receive(:find).and_return @bucket
      end

      it "does not contain bundler, rbenv or rails environment" do
        old_path = ENV['PATH']
        begin
          ENV['RBENV_DIR'] = 'hau mich weg'
          ENV['RBENV_VERSION'] = 'mich auch'
          ENV['RBENV_ROOT'] = '/hier/liegt/rbenv'
          ENV['GEM_PATH'] = "woll'n wa nich"
          ENV['GEM_HOME'] = "dito"
          ENV['RUBYOPT'] = "bittenich"
          ENV['BUNDLE_GEMFILE'] = "unerwünscht"
          ENV['BUNDLE_BIN_PATH'] = "persona non grata"
          ENV['RAILS_ENV'] = "please do not disturb"
          ENV['PATH'] = '/hier/liegt/rbenv/versions/oder/darunter:/ein/pfad/woanders:/hier/liegt/rbenv/versions/oder/so:/keinpfadin/rbenv/versions/sondernwasanderes'

          @worker.run
          %w(
            RBENV_VERSION
            RBENV_DIR
            GEM_PATH
            GEM_HOME
            RUBYOPT
            BUNDLE_GEMFILE
            BUNDLE_BIN_PATH
            RAILS_ENV
          ).each {|key| expect(@perform_task_env.keys).to_not include(key) }
          expect(@perform_task_env['PATH']).
              to eq('/ein/pfad/woanders:/keinpfadin/rbenv/versions/sondernwasanderes')
        ensure
          ENV['PATH'] = old_path
        end
      end

      it "performs the task with the configured ruby version if any" do
        allow(@project).to receive(:ruby_version).with("t2").and_return "1.2.3-p4"
        @worker.run
        expect(@perform_task_env['RBENV_VERSION']).to eq('1.2.3-p4')
      end

      it "performs the task with the configured environment if any" do
        allow(@project).to receive(:bucket_group_environment).with("t2").and_return({
          SOME: "env"
        })
        @worker.run
        expect(@perform_task_env['SOME']).to eq('env')
        expect(@perform_task_env.reject {|k, v| k == 'SOME' }).to_not be_empty
      end
    end

    describe "when performing task" do
      before do
        allow(@worker).to receive(:perform_rake_task).and_return(true)
        allow(@project).to receive(:before_all_tasks).with("t2").and_return %w(bb_1 bb_2)
        allow(@project).to receive(:before_bucket_tasks).with("t2").and_return %w(bt_1 bt_2)
        allow(@project).to receive(:after_bucket_tasks).with("t2").and_return %w(at_1 at_2)
        allow(@project).to receive(:before_each_bucket_group_code).and_return(
            @before_each_bucket_group_code = Proc.new {"code"})
        allow(@project).to receive(:bucket_group).with("t2").and_return 'default'
        allow(@project).to receive(:before_all_code).and_return(@before_all_code = Proc.new {"code"})
        allow(Dir).to receive(:chdir).and_yield
        allow(@worker).to receive(:execute)
        allow(Mailer).to receive(:failure_message).and_return double('mail', deliver: nil)
      end

      describe "when before_each_bucket_group_code is not given" do
        before do
          allow(@project).to receive(:before_each_bucket_group_code).and_return(nil)
        end

        it "should not fail" do
          @worker.perform_task(@bucket)
        end
      end

      describe "when before_all_code is not given" do
        before do
          allow(@project).to receive(:before_all_code).and_return(nil)
        end

        it "should not fail" do
          @worker.perform_task(@bucket)
        end
      end

      describe "of already handled build" do
        before do
          allow(@project).to receive(:bucket_group).and_return "group1"
          allow(@project).to receive(:before_all_tasks).with("t2").and_return %w(bb_2 bb_3 bb_4)
          @worker.perform_task(@bucket)
          allow(@bucket.build).to receive(:id).and_return 321
          allow(@project).to receive(:bucket_group).and_return "group2"
          allow(@project).to receive(:before_all_tasks).with("t2").and_return %w(bb_1 bb_2)
          @worker.perform_task(@bucket)
        end

        it "should not perform the before_all rake tasks" do
          expect(@worker).not_to receive(:perform_rake_task).with('git path', 'bb_1', @logs)
          expect(@worker).not_to receive(:perform_rake_task).with('git path', 'bb_2', @logs)
          @worker.perform_task(@bucket)
        end

        it "should not perform the before_all_code" do
          expect(@before_all_code).not_to receive(:call)
          @worker.perform_task(@bucket)
        end

        context "when project is bundled" do
          before do
            allow(File).to receive(:exists?).with('git path/Gemfile').and_return true
          end

          it "should not perform bundle install" do
            expect(@worker).not_to receive(:execute)
            @worker.perform_task(@bucket)
          end

          context "when bundle was not installed for the requested ruby version" do
            it "should perform bundle install but not the before_all_tasks" do
              expect(@project).to receive(:ruby_version).with(@bucket.name).and_return '1.2.3-p4'
              expect(@worker).to receive(:execute).with(%w(bundle install), {dir: 'git path'})
              expect(@worker).not_to receive(:perform_rake_task).with('git path', 'bb_1', @logs)
              @worker.perform_task(@bucket)
            end
          end
        end

        describe "when project is not bundled" do
          before do
            allow(File).to receive(:exists?).with('git path/Gemfile').and_return false
          end

          it "should not perform bundle install" do
            expect(@worker).not_to receive(:execute)
            @worker.perform_task(@bucket)
          end
        end

        describe "in not yet handled bucket group" do
          before do
            allow(@project).to receive(:bucket_group).and_return "group1"
            allow(@project).to receive(:before_all_tasks).with("t2").and_return %w(bb_2 bb_3 bb_4)
          end

          it "should perform additional before_all rake tasks of this bucket group" do
            expect(@worker).not_to receive(:perform_rake_task).with('git path', 'bb_2', @logs)
            expect(@worker).to receive(:perform_rake_task).with('git path', 'bb_3', @logs)
            expect(@worker).to receive(:perform_rake_task).with('git path', 'bb_4', @logs)
            @worker.perform_task(@bucket)
          end

          it "should perform the before_each_bucket_group_code" do
            expect(Dir).to receive(:chdir).with('git path').ordered
            expect(@before_each_bucket_group_code).to receive(:call).ordered
            @worker.perform_task(@bucket)
          end
        end

        describe "in already handled bucket group" do
          before do
            allow(@project).to receive(:bucket_group).and_return "group1"
            allow(@project).to receive(:before_all_tasks).with("t2").and_return %w(bb_2 bb_3 bb_4)
            @worker.perform_task(@bucket)
          end

          it "should not perform before_all rake tasks" do
            expect(@worker).not_to receive(:perform_rake_task).with('git path', 'bb_2', @logs)
            expect(@worker).not_to receive(:perform_rake_task).with('git path', 'bb_3', @logs)
            expect(@worker).not_to receive(:perform_rake_task).with('git path', 'bb_4', @logs)
            @worker.perform_task(@bucket)
          end

          it "should not perform the before_each_bucket_group_code" do
            expect(@before_each_bucket_group_code).not_to receive(:call)
            @worker.perform_task(@bucket)
          end
        end
      end

      describe "of build which is handled for the first time" do
        before do
          @worker.perform_task(@bucket)
          allow(@bucket.build).to receive(:id).and_return 321
        end

        it "should perform the before_all_code prior to the before_all rake tasks" do
          expect(Dir).to receive(:chdir).with('git path').ordered
          expect(@before_all_code).to receive(:call).ordered
          expect(@worker).to receive(:perform_rake_task).with('git path', 'bb_1', @logs).ordered
          @worker.perform_task(@bucket)
        end

        describe "when project is bundled" do
          before do
            allow(File).to receive(:exists?).with('git path/Gemfile').and_return true
          end

          it "should perform bundle install prior to the before_all rake tasks" do
            expect(@worker).to receive(:execute).with(%w(bundle install), {:dir => 'git path'}).ordered
            expect(@worker).to receive(:perform_rake_task).with('git path', 'bb_1', @logs).ordered
            @worker.perform_task(@bucket)
          end
        end

        describe "when project is not bundled" do
          before do
            allow(File).to receive(:exists?).with('git path/Gemfile').and_return false
          end

          it "should not perform bundle install" do
            expect(@worker).not_to receive(:execute)
            @worker.perform_task(@bucket)
          end
        end

        it "should perform the before_all rake tasks prior to the task's rake tasks" do
          expect(@worker).to receive(:perform_rake_task).with('git path', 'bb_1', @logs).ordered
          expect(@worker).to receive(:perform_rake_task).with('git path', 'bb_2', @logs).ordered
          expect(@worker).to receive(:perform_rake_task).with('git path', 'bt_1', @logs).ordered
          @worker.perform_task(@bucket)
        end

        it "should perform the before_each_bucket_group_code" do
          expect(Dir).to receive(:chdir).with('git path').ordered
          expect(@before_each_bucket_group_code).to receive(:call).ordered
          @worker.perform_task(@bucket)
        end

        it "should set the state to failed when processing of a before_all rake task failed" do
          expect(@worker).to receive(:perform_rake_task).with('git path', 'bb_1', @logs).
              and_return(false)
          expect(@bucket).to receive(:status=).with(40).ordered
          expect(@bucket).to receive(:save).ordered
          @worker.perform_task(@bucket)
        end

        it "should not perform the after_each_bucket tasks if a before_all task failed" do
          expect(@worker).to receive(:perform_rake_task).with('git path', "bb_1", @logs).
              and_return false
          expect(@worker).not_to receive(:perform_rake_task).with('git path', 'at_1', @logs)
          expect(@worker).not_to receive(:perform_rake_task).with('git path', 'at_2', @logs)
          @worker.perform_task(@bucket)
        end
      end

      it "should perform all the rake tasks for the task one by one on the updated git path" do
        allow(@git).to receive(:current_commit).and_return 'the commit'
        expect(@git).to receive(:update).with(:commit => 'the commit', :make_pristine => false).ordered
        expect(@worker).to receive(:perform_rake_task).with('git path', 'bt_1', @logs).ordered
        expect(@worker).to receive(:perform_rake_task).with('git path', 'bt_2', @logs).ordered
        expect(@worker).to receive(:perform_rake_task).with('git path', 'rt21', @logs).ordered
        expect(@worker).to receive(:perform_rake_task).with('git path', 'rt22', @logs).ordered
        expect(@worker).to receive(:perform_rake_task).with('git path', 'at_1', @logs).ordered
        expect(@worker).to receive(:perform_rake_task).with('git path', 'at_2', @logs).ordered
        @worker.perform_task(@bucket)
      end

      it "should make a pristine environment when the commit has changed" do
        allow(@git).to receive(:current_commit).and_return 'other commit'
        expect(@git).to receive(:update).with(:commit => 'the commit', :make_pristine => true)
        @worker.perform_task(@bucket)
      end

      it "should move the logs into the bucket when processing has finished" do
        expect(@bucket).to receive(:log=).with("log1log2").ordered
        expect(@bucket).to receive(:save).ordered
        expect(@logs).to receive(:clear).ordered
        @worker.perform_task(@bucket)
      end

      it "should set the state to failed when processing the first task fails" do
        expect(@worker).to receive(:perform_rake_task).and_return(false)
        expect(@bucket).to receive(:status=).with(40).ordered
        expect(@bucket).to receive(:save).ordered
        @worker.perform_task(@bucket)
      end

      it "should set the state to failed when processing the second task fails" do
        expect(@worker).to receive(:perform_rake_task).and_return(true, false)
        expect(@bucket).to receive(:status=).with(40).ordered
        expect(@bucket).to receive(:save).ordered
        @worker.perform_task(@bucket)
      end

      it "should set the state to done when processing has finished successfully" do
        expect(@worker).to receive(:perform_rake_task).and_return(true, true)
        expect(@bucket).to receive(:status=).with(10).ordered
        expect(@bucket).to receive(:save).ordered
        @worker.perform_task(@bucket)
      end

      it "should perform the after_each_bucket tasks even if a before_each_bucket task failed" do
        expect(@worker).to receive(:perform_rake_task).with('git path', "bt_1", @logs).and_return false
        expect(@worker).to receive(:perform_rake_task).with('git path', 'at_1', @logs)
        expect(@worker).to receive(:perform_rake_task).with('git path', 'at_2', @logs)
        @worker.perform_task(@bucket)
      end

      it "should perform the after_each_bucket tasks even if a bucket task failed" do
        expect(@worker).to receive(:perform_rake_task).with('git path', "rt21", @logs).and_return false
        expect(@worker).to receive(:perform_rake_task).with('git path', 'at_1', @logs)
        expect(@worker).to receive(:perform_rake_task).with('git path', 'at_2', @logs)
        @worker.perform_task(@bucket)
      end

      it "should set the state to failed when processing an after_each_bucket task fails" do
        expect(@worker).to receive(:perform_rake_task).with('git path', "at_1", @logs).and_return false
        expect(@bucket).to receive(:status=).with(40).ordered
        expect(@bucket).to receive(:save).ordered
        @worker.perform_task(@bucket)
      end

      it "should store the current time into bucket's finished_at when processing has finished" do
        now = Time.now
        allow(Time).to receive(:now).and_return now
        expect(@bucket).to receive(:finished_at=).with(now).ordered
        expect(@bucket).to receive(:save).ordered
        @worker.perform_task(@bucket)
      end
    end

    describe "when performing rake task" do
      before do
        @rake = TestRake.new
        allow(Rake).to receive(:new) do |path, log_file|
          @rake.log_file = log_file
          @rake
        end
      end

      after do
        TestRake.cleanup
      end

      it "should perform the rake task in the given path" do
        # „fork“ muss stubbed werden, da die Expectations nicht über Prozessgrenzen hinaus
        # funktionieren.
        allow(@worker).to receive(:fork).and_yield.and_return(-13)
        allow(@worker).to receive(:exit)
        allow(@worker).to receive(:exit!)
        allow(Process).to receive(:waitpid).with(-13, Process::WNOHANG) do
          fork {exit! 0}
          Process.wait
        end
        allow(File).to receive(:read)

        expect(Rake).to receive(:new) do |path, log_file|
          expect(path).to eq('path')
          @rake.log_file = log_file
          @rake
        end
        expect(@rake).to receive(:rake).with('task')
        @worker.perform_rake_task('path', 'task', nil)
      end

      it "should use a log file in its log dir" do
        expect(Rake).to receive(:new) do |path, log_file|
          expect(log_file).to be_start_with("#{File.expand_path("../../../log", __FILE__)}/")
          @rake.log_file = log_file
          @rake
        end
        allow(@rake).to receive(:rake)
        @worker.perform_rake_task('path', 'task', nil)
      end

      it "should write the output of a task every few seconds into the db" do
        expect(@logs).to receive(:create).once.with(:log => "first fünf rake output\n").ordered
        expect(@logs).to receive(:create).once.with(:log => "€second fünf rake output\n").ordered
        expect(@logs).to receive(:create).once.with(:log => "€third fünf rake output\n").ordered
        expect(@logs).to receive(:create).once.with(:log => "€last fünf rake output\n").ordered
        @worker.perform_rake_task('path', 'task', @logs)
      end

      it "should not create a log piece in the db if there is no output" do
        allow(@rake).to receive(:rake)
        expect(@logs).not_to receive(:create)
        @worker.perform_rake_task('path', 'task', @logs)
      end

      it "should return false if rake failed" do
        allow(@rake).to receive(:rake).and_raise "rake failure"
        expect(@worker.perform_rake_task('path', 'task', @logs)).to be_falsey
      end

      it "should return true if rake succeeded" do
        allow(@rake).to receive(:rake)
        expect(@worker.perform_rake_task('path', 'task', @logs)).to be_truthy
      end
    end
  end
end

describe Worker, "when running as leader" do
  def project_double(name, current_commit, next_build_number)
    m = double(name, :name => name, :wants_build? => false, :current_commit => current_commit,
        :id => "#{name}_id", :builds => [], :dependencies => [],
        :buckets_tasks => {"#{name}1" => "tasks1", "#{name}2" => "tasks2", "#{name}3" => "tasks3"})
    expect(m).to receive(:next_build_number).at_most(:once).and_return(next_build_number)
    allow(m).to receive(:update_state)
    allow(m).to receive(:last_system_error=)
    allow(m).to receive(:save)
    allow(m).to receive(:last_build)
    m
  end

  before do
    @project1 = project_double("p1", "12", 2)
    @project2 = project_double("p2", "34", 4)
    @project3 = project_double("p3", "56", 6)
    @project4 = project_double("p4", "78", 8)
    allow(Project).to receive(:find).with(:all).and_return [@project1, @project2, @project3, @project4]
    @leader = Worker.new('dcc_test', nil, :log_level => ::Logger::FATAL)
  end

  let(:leader) { @leader }
  let(:memcache_client) { double(Dalli::Client, add: nil, get: nil) }

  shared_examples_for "finishing build" do
    describe "when finishing the last build" do
      before do
        allow(Project).to receive(:find).with(:all).and_return [@project1]
        allow(@project1).to receive(:last_build).and_return(@last_build = double('b', :finished_at => Time.now))
      end

      it "should clean up dead buckets by calling 'project_in_build?'" do
        expect(@leader).to receive(:project_in_build?).with(@project1)
        @leader.send(@method_under_test, memcache_client)
      end

      describe "when a project is not in build" do
        before do
          allow(@last_build).to receive(:identifier).and_return 'nix'
          allow(@leader).to receive(:project_in_build?).with(@project1).and_return false
        end

        it "should set the last build's finished_at to now when it's empty" do
          allow(@last_build).to receive(:finished_at).and_return nil
          now = Time.now
          allow(Time).to receive(:now).and_return now
          expect(@last_build).to receive(:finished_at=).with(now).ordered
          expect(@last_build).to receive(:save).ordered
          @leader.send(@method_under_test, memcache_client)
        end

        it "should not change the last build's finished_at when it's already set" do
          allow(@last_build).to receive(:finished_at).and_return Time.now
          expect(@last_build).not_to receive(:finished_at=)
          expect(@last_build).not_to receive(:save)
          @leader.send(@method_under_test, memcache_client)
        end

        it "should not fail if project was never built" do
          allow(@project1).to receive(:last_build).and_return nil
          @leader.send(@method_under_test, memcache_client)
        end
      end

      describe "when a project is in build" do
        before do
          allow(@leader).to receive(:project_in_build?).with(@project1).and_return true
        end

        it "should not change the last build's finished_at regardless of it's state" do
          expect(@last_build).not_to receive(:finished_at=)
          expect(@last_build).not_to receive(:save)
          @leader.update_buckets(memcache_client)
        end
      end
    end
  end

  describe "when initializing the buckets" do
    before do
      @method_under_test = :initialize_buckets
    end

    it_should_behave_like "finishing build"

    it "should read and set the buckets for every project" do
      expect(@leader).to receive(:read_buckets).exactly(4).times do |memcache_client, p|
        "#{p.name}_buckets"
      end
      expect(@leader.buckets).to receive(:set_buckets).with('p1', 'p1_buckets')
      expect(@leader.buckets).to receive(:set_buckets).with('p2', 'p2_buckets')
      expect(@leader.buckets).to receive(:set_buckets).with('p3', 'p3_buckets')
      expect(@leader.buckets).to receive(:set_buckets).with('p4', 'p4_buckets')
      @leader.initialize_buckets(memcache_client)
    end
  end

  describe "when updating the buckets" do
    before do
      @method_under_test = :update_buckets
    end

    it_should_behave_like "finishing build"

    it "should read and set for every project which is not actually build" do
      allow(@leader).to receive(:project_in_build?) {|p| p.name =~ /p[13]/}

      expect(@leader).to receive(:read_buckets).exactly(2).times do |memcache_client, p|
        "new_#{p.name}_buckets"
      end

      expect(@leader.buckets).to receive(:set_buckets).with('p2', 'new_p2_buckets')
      expect(@leader.buckets).to receive(:set_buckets).with('p4', 'new_p4_buckets')

      @leader.update_buckets(memcache_client)
    end
  end

  describe "when determining if project is being build" do
    before do
      @project = double('project', :name => 'p')
    end

    it "should say yes when there are buckets pending" do
      @leader.buckets.set_buckets 'p', ['buckets']
      expect(@leader).to be_project_in_build(@project)
    end

    describe "when there are no buckets left" do
      before do
        @leader.buckets.set_buckets 'p', []
      end

      it "should say no when there never was a build" do
        allow(@project).to receive(:last_build).and_return nil
        expect(@leader).not_to be_project_in_build(@project)
      end

      it "should say no when all buckets are processed" do
        allow(@project).to receive(:last_build).and_return(double('b', :buckets => [
          double('b1', :status => 10),
          double('b2', :status => 35),
          double('b3', :status => 40),
        ]))
        expect(@leader).not_to be_project_in_build(@project)
      end

      it "should not matter if the pending buckets array is nil or empty" do
        allow(@project).to receive(:last_build)

        @leader.buckets.set_buckets 'p', nil
        expect(@leader).not_to be_project_in_build(@project)

        @leader.buckets.set_buckets 'p', []
        expect(@leader).not_to be_project_in_build(@project)
      end

      shared_examples_for "dead or unreachable workers" do
        before do
          allow(@bucket).to receive(:status=)
          allow(@bucket).to receive(:save)
          allow(@bucket).to receive(:worker_uri).and_return "worker's uri"
          allow(@bucket).to receive(:id).and_return 'bucket_id'
          allow(@bucket).to receive(:log)
          allow(@bucket).to receive(:log=)
          allow(@leader).to receive(:load_bucket_with_logs).with('bucket_id').and_return(@bucket)
        end

        it "should say no" do
          expect(@leader).not_to be_project_in_build(@project)
        end

        it "should set the bucket's status to 'processing_failed'" do
          expect(@bucket).to receive(:status=).with(35).ordered
          expect(@bucket).to receive(:save).ordered
          @leader.project_in_build?(@project)
        end

        it "fills the bucket's log with error info" do
          expect(@bucket).to receive(:log=).ordered do |msg|
            expect(msg).to match('Processing failed')
          end
          expect(@bucket).to receive(:save).ordered
          @leader.project_in_build?(@project)
        end
      end

      describe "when buckets are pending" do
        before do
          allow(@project).to receive(:last_build).and_return(double('b', :buckets => [
            @bucket = double('b1', :status => 20)
          ]))
        end

        it_should_behave_like "dead or unreachable workers"
      end

      describe "when a bucket is in work" do
        before do
          allow(@project).to receive(:last_build).and_return(double('b', :buckets => [
            @bucket = double('b1', :status => 30, :id => 666)
          ]))
          allow(DRbObject).to receive(:new).with(nil, "worker's uri").and_return(@worker = double('w'))
        end

        describe "when the worker is alive and processing the bucket in question" do
          before do
            allow(@bucket).to receive(:worker_uri).and_return "worker's uri"
            allow(@worker).to receive(:processing?).with(666).and_return true
          end

          it "should say yes" do
            expect(@leader).to be_project_in_build(@project)
          end
        end

        describe "when the worker is alive but does not process the bucket in question" do
          before do
            allow(@worker).to receive(:processing?).with(666).and_return false
          end

          it_should_behave_like "dead or unreachable workers"
        end

        describe "when the worker is not reachable" do
          before do
            allow(@worker).to receive(:processing?).with(666).and_raise DRb::DRbConnError.new('nix da')
          end

          it_should_behave_like "dead or unreachable workers"
        end
      end
    end
  end

  describe "when reading the buckets" do
    before do
      allow(@project1.builds).to receive(:create).and_return(changed_build = double('', :buckets => double('')))
      allow(@project2.builds).to receive(:create).and_return(unchanged_build = double('', :buckets => double('')))
      allow(@project1).to receive(:wants_build?).and_return true
      allow(@project2).to receive(:wants_build?).and_return false
      allow(changed_build.buckets).to receive(:create) do |m|
        double(m[:name], :id => "#{m[:name]}_id")
      end
      allow(unchanged_build.buckets).to receive(:create) do |m|
        double(m[:name], :id => "#{m[:name]}_id")
      end
      allow(@leader).to receive(:uri).and_return "leader's uri"
      allow(Socket).to receive(:gethostname).and_return "leader's hostname"
    end

    it "should return changed buckets" do
      buckets = @leader.read_buckets(memcache_client, @project1)
      expect(buckets.size).to eq(3)
      expect(buckets).to be_include('p11_id')
      expect(buckets).to be_include('p12_id')
      expect(buckets).to be_include('p13_id')
    end

    it "should not return unchanched buckets" do
      expect(@leader.read_buckets(memcache_client, @project2)).to be_empty
    end

    it "should update the projects state if buckets were read" do
      expect(@project1).to receive(:update_state)
      @leader.read_buckets(memcache_client, @project1)
    end

    it "should not update the projects state if buckets were not read" do
      expect(@project2).not_to receive(:update_state)
      @leader.read_buckets(memcache_client, @project2)
    end

    it "creates the build and the buckets in the db" do
      expect(@project1.builds).to receive(:create).with(commit: "12", build_number: 2,
          leader_uri: "leader's uri", leader_hostname: "leader's hostname").
          and_return(build = double('', :buckets => double('')))
      [1, 2, 3].each do |task|
        expect(build.buckets).to receive(:create).with(:name => "p1#{task}", :status => 20).
            and_return(double('', :id => 1))
      end
      @leader.read_buckets(memcache_client, @project1)
    end

    it "should set the error into the database if an error occurs" do
      allow(@leader).to receive(:leader_uri)
      allow(@project1).to receive(:update_state).and_raise "an error"

      expect(@project1).to receive(:last_system_error=).with(/reading buckets failed.*an error/m).
          ordered
      expect(@project1).to receive(:save).ordered

      @leader.read_buckets(memcache_client, @project1)
    end

    it "should set the error into the database even if a LoadError error occurs" do
      allow(@leader).to receive(:leader_uri)
      allow(@project1).to receive(:update_state).and_raise LoadError.new('nix da')

      expect(@project1).to receive(:last_system_error=).with(/reading buckets failed.*nix da/m).ordered
      expect(@project1).to receive(:save).ordered

      @leader.read_buckets(memcache_client, @project1)
    end

    it "should unset the error in the database if no error occurs" do
      allow(@leader).to receive(:leader_uri)
      allow(@project1).to receive(:update_state)

      expect(@project1).to receive(:last_system_error=).with(nil).ordered
      expect(@project1).to receive(:save).ordered

      @leader.read_buckets(memcache_client, @project1)
    end

    it "should not unset the error in the database if an error occurs" do
      allow(@leader).to receive(:leader_uri)
      allow(@project1).to receive(:update_state).and_raise "an error"

      expect(@project1).not_to receive(:last_system_error=).with(nil)

      @leader.read_buckets(memcache_client, @project1)
    end
  end

  describe "when delivering buckets" do
    before do
      @bucket = double('bucket', :worker_uri= => nil, :status= => nil, :save => nil, :id => 123,
          :started_at= => nil, :worker_hostname= => nil,
          :build => double('build', :started_at => nil, :started_at= => nil, :save => nil))
      allow(Bucket).to receive(:find).with(123).and_return(@bucket)
      allow(@leader.buckets).to receive(:next_bucket).and_return(123)
      allow(@leader).to receive(:sleep_until_next_bucket_time).and_return(0)
    end

    it "should deliver the next bucket from the bucket store" do
      allow(Bucket).to receive(:find).with("next bucket").and_return(@bucket)

      expect(@leader.buckets).to receive(:next_bucket).and_return("next bucket")
      expect(@leader).to receive(:sleep_until_next_bucket_time).and_return(666)
      expect(@leader.next_bucket("requestor", {})).to eq(["next bucket", 666])
    end

    it "should store the requestor's uri into the bucket" do
      expect(@bucket).to receive(:worker_uri=).with("requestor").ordered
      expect(@bucket).to receive(:save).ordered
      @leader.next_bucket("requestor", {})
    end

    it "should store the status 'in work' into the bucket" do
      expect(@bucket).to receive(:status=).with(30).ordered
      expect(@bucket).to receive(:save).ordered
      @leader.next_bucket("requestor", {})
    end

    it "should store the current time for started_at into the bucket" do
      started_at = Time.now
      allow(Time).to receive(:now).and_return(started_at)
      expect(@bucket).to receive(:started_at=).with(started_at).ordered
      expect(@bucket).to receive(:save).ordered
      @leader.next_bucket("requestor", {})
    end

    it "should store the current time for started_at into the build iff it's the first bucket" do
      allow(@bucket).to receive(:build).and_return(build = double('build', :started_at => nil))
      started_at = Time.now
      allow(Time).to receive(:now).and_return(started_at)
      expect(build).to receive(:started_at=).with(started_at).ordered
      expect(build).to receive(:save).ordered
      @leader.next_bucket("requestor", {})
      allow(build).to receive(:started_at).and_return started_at
      @leader.next_bucket("requestor", {})
    end

    it "should store the requestor's hostname into the bucket" do
      expect(@bucket).to receive(:worker_hostname=).with("requestor's hostname").ordered
      expect(@bucket).to receive(:save).ordered
      @leader.next_bucket("requestor", {hostname: "requestor's hostname"})
    end

    describe "when no buckets are left" do
      before do
        allow(@leader.buckets).to receive(:next_bucket).and_return(nil)
      end

      it "should not try to change bucket" do
        expect(Bucket).not_to receive(:find)
        @leader.next_bucket("requestor", {})
      end

      it "should deliver the nil bucket" do
        expect(@leader.next_bucket("requestor", {})).to eq([nil, 0])
      end
    end
  end

  context "before performing the leader duties" do
    let(:state) { ClusterState.instance.tap {|i| allow(ClusterState).to receive(:instance).and_return i } }

    before do
      allow_any_instance_of(EC2).to receive(:neighbours).
          and_return([double('instance', tags: {'dcc:dcc_test:uri' => 'the_uri'})] * 5)
    end

    it "updates the cluster state's minion count" do
      expect(state).to receive(:minion_count=).with(5).ordered
      expect(state).to receive(:save).ordered
      leader.before_perform_leader_duties
    end

    context "when minion count has not changed" do
      before do
        allow(state).to receive(:minion_count).and_return 5
      end

      it "does not update the cluster state" do
        expect(state).to_not receive :minion_count=
        expect(state).to_not receive :save
        leader.before_perform_leader_duties
      end
    end
  end
end

end
