# encoding: utf-8
require File.dirname(__FILE__) + '/../spec_helper'

require 'dcc/rake'
require 'dcc/worker'

module DCC

class Worker
  attr_accessor :buckets
  attr_reader :memcache_client

  def cleanup
  end

  def log_polling_intervall
    return 0.1
  end

  def as_dictator
    yield
  end
end

class TestRake < Rake
  def initialize
    FileUtils.mkdir_p self.class.path
    super(self.class.path)
  end

  def self.path
    'tmp'
  end

  def self.cleanup
    FileUtils.rm_rf path
  end

  def rake(*args)
    File.open(log_file, "w:iso-8859-1") do |f|
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
      Socket.stub(:gethostname).and_return "Scooby Doo"
      worker.bucket_request_context[:hostname].should == "Scooby Doo"
    end
  end

  describe "when performing operation protected against MySQL failures" do
    it "should return the block's result if MySQL did not fail" do
      worker.send(:retry_on_mysql_failure) do
        "das ergebnis"
      end.should == "das ergebnis"
    end

    it "should return the block's result if MySQL fails once and succeeds afterwards" do
      failed = false
      worker.send(:retry_on_mysql_failure) do
        unless failed
          failed = true
          raise ActiveRecord::StatementInvalid.new("MySQL server has gone away")
        end
        "das ergebnis"
      end.should == "das ergebnis"
    end
  end
end

describe Worker, "when running as follower" do
  before do
    @worker = Worker.new('dcc_test', nil, :log_level => ::Logger::ERROR)
    leader = Worker.new('dcc_test', nil, :log_level => ::Logger::ERROR)
    @worker.stub(:leader).and_return leader
    leader.stub(:bucket_request).and_return ["b_id1", 10], ["b_id2", 10], ["b_id3", 10], [nil, 10]
    @worker.memcache_client.stub(:add)
    @worker.memcache_client.stub(:get).and_return(leader.uri)
    @worker.stub(:loop?).and_return true, true, false
    @worker.send(:log).level = ::Logger::FATAL
    Bucket.stub(:find)
    Bucket.stub(:find).with("b_id1").and_return("bucket 1")
    Bucket.stub(:find).with("b_id2").and_return("bucket 2")
    Bucket.stub(:find).with("b_id3").and_return("bucket 3")
  end

  it "should perform all tasks given from leader" do
    @worker.should_receive(:perform_task).with("bucket 1")
    @worker.should_receive(:perform_task).with("bucket 2")
    @worker.should_receive(:perform_task).with("bucket 3")
    @worker.run
  end

  it "should perform the tasks without bundler, rbenv or rails environment" do
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

      @worker.stub(:perform_task) { @perform_task_env = ENV.to_hash }
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
      ).each {|key| @perform_task_env.keys.should_not include(key) }
      @perform_task_env['PATH'].should ==
          '/ein/pfad/woanders:/keinpfadin/rbenv/versions/sondernwasanderes'
    ensure
      ENV['PATH'] = old_path
    end
  end

  describe 'when determining if it is processing a specific bucket' do
    before do
      @worker.stub(:perform_task)
      @worker.stub(:loop?).and_return false
    end

    it "should say no if no bucket is being processed" do
      @worker.leader.stub(:bucket_request).and_return [nil, 1]
      @worker.run
      @worker.should_not be_processing('b_id1')
    end

    it "should say no if another bucket is being processed" do
      @worker.leader.stub(:bucket_request).and_return ['b_id2', 1], [nil, 1]
      @worker.run
      @worker.should_not be_processing('b_id1')
    end

    it "should say yes if the bucket is being processed" do
      @worker.leader.stub(:bucket_request).and_return ['b_id1', 1], [nil, 1]
      @worker.run
      @worker.should be_processing('b_id1')
    end
  end

  describe 'when even the basic things (process_bucket) fail' do
    before do
      @worker.stub(:process_bucket).and_raise("an error")
    end

    it "should send an email to the admin" do
      @worker.stub(:admin_e_mail_address).and_return('admin-e-mail')
      Mailer.should_receive(:dcc_message).with('admin-e-mail', 'running worker failed', /an error/).
          and_return(message = double)
      message.should_receive(:deliver)
      @worker.run
    end
  end

  describe 'when perform_task fails' do
    before do
      @worker.stub(:loop?).and_return false
      Bucket.stub(:find).and_return(@bucket = double('bucket', :status= => nil, :save => nil,
          :log= => nil, :log => 'old_log', :build => double('build', :leader_hostname => nil)))
      @worker.stub(:perform_task).and_raise("an error")
    end

    it "should set bucket's status to 'processing failed'" do
      @bucket.should_receive(:status=).with(35).ordered
      @bucket.should_receive(:save).ordered
      @worker.run
    end

    it "should set the error into the database" do
      @bucket.should_receive(:log=).with(/old_log.*processing bucket failed.*an error/m).ordered
      @bucket.should_receive(:save).ordered
      @worker.run
    end

    it "should set the error into the database even if no log exists" do
      @bucket.stub(:log).and_return nil
      @bucket.should_receive(:log=).with(/.*processing bucket failed.*an error/m).ordered
      @bucket.should_receive(:save).ordered
      @worker.run
    end
  end

  describe '' do
    before do
      @git = double('git', :path => 'git path', :update => nil, :current_commit => nil)
      @project = double('project', :name => "project's name", :before_all_tasks => [], :git => @git,
          :e_mail_receivers => [], :before_bucket_tasks => [], :after_bucket_tasks => [], :id => 1,
          :last_build => nil)
      @project.stub(:bucket_tasks).with('t1').and_return(['rt1'])
      @project.stub(:bucket_tasks).with('t2').and_return(['rt21', 'rt22'])
      @logs = [double('l1', :log => 'log1'), double('l2', :log => 'log2')]
      @bucket = double('bucket', :name => "t2", :log= => nil, :finished_at= => nil,
          :build => double('build', :id => 123, :identifier => 'the commit.666',
          :project => @project, :commit => 'the commit', :build_number => 666),
          :save => nil, :logs => @logs, :status= => nil, :log => "nothing to say here",
          :build_error_log => nil, :error_log => nil)
    end

    describe "when performing task" do
      before do
        @worker.stub(:perform_rake_task).and_return(true)
        @project.stub(:before_all_tasks).with("t2").and_return %w(bb_1 bb_2)
        @project.stub(:before_bucket_tasks).with("t2").and_return %w(bt_1 bt_2)
        @project.stub(:after_bucket_tasks).with("t2").and_return %w(at_1 at_2)
        @project.stub(:before_each_bucket_group_code).and_return(
            @before_each_bucket_group_code = Proc.new {"code"})
        @project.stub(:bucket_group).with("t2").and_return 'default'
        @project.stub(:before_all_code).and_return(@before_all_code = Proc.new {"code"})
        Dir.stub(:chdir).and_yield
        @worker.stub(:execute)
        Mailer.stub(:failure_message).and_return double('mail', deliver: nil)
      end

      describe "when before_each_bucket_group_code is not given" do
        before do
          @project.stub(:before_each_bucket_group_code).and_return(nil)
        end

        it "should not fail" do
          @worker.perform_task(@bucket)
        end
      end

      describe "when before_all_code is not given" do
        before do
          @project.stub(:before_all_code).and_return(nil)
        end

        it "should not fail" do
          @worker.perform_task(@bucket)
        end
      end

      describe "of already handled build" do
        before do
          @project.stub(:bucket_group).and_return "group1"
          @project.stub(:before_all_tasks).with("t2").and_return %w(bb_2 bb_3 bb_4)
          @worker.perform_task(@bucket)
          @bucket.build.stub(:id).and_return 321
          @project.stub(:bucket_group).and_return "group2"
          @project.stub(:before_all_tasks).with("t2").and_return %w(bb_1 bb_2)
          @worker.perform_task(@bucket)
        end

        it "should not perform the before_all rake tasks" do
          @worker.should_not_receive(:perform_rake_task).with('git path', 'bb_1', @logs)
          @worker.should_not_receive(:perform_rake_task).with('git path', 'bb_2', @logs)
          @worker.perform_task(@bucket)
        end

        it "should not perform the before_all_code" do
          @before_all_code.should_not_receive(:call)
          @worker.perform_task(@bucket)
        end

        describe "when project is bundled" do
          it "should not perform bundle install" do
            @worker.should_not_receive(:execute)
            @worker.perform_task(@bucket)
          end
        end

        describe "when project is not bundled" do
          it "should not perform bundle install" do
            @worker.should_not_receive(:execute)
            @worker.perform_task(@bucket)
          end
        end

        describe "in not yet handled bucket group" do
          before do
            @project.stub(:bucket_group).and_return "group1"
            @project.stub(:before_all_tasks).with("t2").and_return %w(bb_2 bb_3 bb_4)
          end

          it "should perform additional before_all rake tasks of this bucket group" do
            @worker.should_not_receive(:perform_rake_task).with('git path', 'bb_2', @logs)
            @worker.should_receive(:perform_rake_task).with('git path', 'bb_3', @logs)
            @worker.should_receive(:perform_rake_task).with('git path', 'bb_4', @logs)
            @worker.perform_task(@bucket)
          end

          it "should perform the before_each_bucket_group_code" do
            Dir.should_receive(:chdir).with('git path').ordered
            @before_each_bucket_group_code.should_receive(:call).ordered
            @worker.perform_task(@bucket)
          end
        end

        describe "in already handled bucket group" do
          before do
            @project.stub(:bucket_group).and_return "group1"
            @project.stub(:before_all_tasks).with("t2").and_return %w(bb_2 bb_3 bb_4)
            @worker.perform_task(@bucket)
          end

          it "should not perform before_all rake tasks" do
            @worker.should_not_receive(:perform_rake_task).with('git path', 'bb_2', @logs)
            @worker.should_not_receive(:perform_rake_task).with('git path', 'bb_3', @logs)
            @worker.should_not_receive(:perform_rake_task).with('git path', 'bb_4', @logs)
            @worker.perform_task(@bucket)
          end

          it "should not perform the before_each_bucket_group_code" do
            @before_each_bucket_group_code.should_not_receive(:call)
            @worker.perform_task(@bucket)
          end
        end
      end

      describe "of build which is handled for the first time" do
        before do
          @worker.perform_task(@bucket)
          @bucket.build.stub(:id).and_return 321
        end

        it "should perform the before_all_code prior to the before_all rake tasks" do
          Dir.should_receive(:chdir).with('git path').ordered
          @before_all_code.should_receive(:call).ordered
          @worker.should_receive(:perform_rake_task).with('git path', 'bb_1', @logs).ordered
          @worker.perform_task(@bucket)
        end

        describe "when project is bundled" do
          before do
            File.stub(:exists?).with('git path/Gemfile').and_return true
          end

          it "should perform bundle install prior to the before_all rake tasks" do
            @worker.should_receive(:execute).with(%w(bundle install), {:dir => 'git path'}).ordered
            @worker.should_receive(:perform_rake_task).with('git path', 'bb_1', @logs).ordered
            @worker.perform_task(@bucket)
          end
        end

        describe "when project is not bundled" do
          before do
            File.stub(:exists?).with('git path/Gemfile').and_return false
          end

          it "should not perform bundle install" do
            @worker.should_not_receive(:execute)
            @worker.perform_task(@bucket)
          end
        end

        it "should perform the before_all rake tasks prior to the task's rake tasks" do
          @worker.should_receive(:perform_rake_task).with('git path', 'bb_1', @logs).ordered
          @worker.should_receive(:perform_rake_task).with('git path', 'bb_2', @logs).ordered
          @worker.should_receive(:perform_rake_task).with('git path', 'bt_1', @logs).ordered
          @worker.perform_task(@bucket)
        end

        it "should perform the before_each_bucket_group_code" do
          Dir.should_receive(:chdir).with('git path').ordered
          @before_each_bucket_group_code.should_receive(:call).ordered
          @worker.perform_task(@bucket)
        end

        it "should set the state to failed when processing of a before_all rake task failed" do
          @worker.should_receive(:perform_rake_task).with('git path', 'bb_1', @logs).
              and_return(false)
          @bucket.should_receive(:status=).with(40).ordered
          @bucket.should_receive(:save).ordered
          @worker.perform_task(@bucket)
        end

        it "should not perform the after_each_bucket tasks if a before_all task failed" do
          @worker.should_receive(:perform_rake_task).with('git path', "bb_1", @logs).
              and_return false
          @worker.should_not_receive(:perform_rake_task).with('git path', 'at_1', @logs)
          @worker.should_not_receive(:perform_rake_task).with('git path', 'at_2', @logs)
          @worker.perform_task(@bucket)
        end
      end

      it "should perform all the rake tasks for the task one by one on the updated git path" do
        @git.stub(:current_commit).and_return 'the commit'
        @git.should_receive(:update).with(:commit => 'the commit', :make_pristine => false).ordered
        @worker.should_receive(:perform_rake_task).with('git path', 'bt_1', @logs).ordered
        @worker.should_receive(:perform_rake_task).with('git path', 'bt_2', @logs).ordered
        @worker.should_receive(:perform_rake_task).with('git path', 'rt21', @logs).ordered
        @worker.should_receive(:perform_rake_task).with('git path', 'rt22', @logs).ordered
        @worker.should_receive(:perform_rake_task).with('git path', 'at_1', @logs).ordered
        @worker.should_receive(:perform_rake_task).with('git path', 'at_2', @logs).ordered
        @worker.perform_task(@bucket)
      end

      it "should make a pristine environment when the commit has changed" do
        @git.stub(:current_commit).and_return 'other commit'
        @git.should_receive(:update).with(:commit => 'the commit', :make_pristine => true)
        @worker.perform_task(@bucket)
      end

      it "should move the logs into the bucket when processing has finished" do
        @bucket.should_receive(:log=).with("log1log2").ordered
        @bucket.should_receive(:save).ordered
        @logs.should_receive(:clear).ordered
        @worker.perform_task(@bucket)
      end

      it "should set the state to failed when processing the first task fails" do
        @worker.should_receive(:perform_rake_task).and_return(false)
        @bucket.should_receive(:status=).with(40).ordered
        @bucket.should_receive(:save).ordered
        @worker.perform_task(@bucket)
      end

      it "should set the state to failed when processing the second task fails" do
        @worker.should_receive(:perform_rake_task).and_return(true, false)
        @bucket.should_receive(:status=).with(40).ordered
        @bucket.should_receive(:save).ordered
        @worker.perform_task(@bucket)
      end

      it "should set the state to done when processing has finished successfully" do
        @worker.should_receive(:perform_rake_task).and_return(true, true)
        @bucket.should_receive(:status=).with(10).ordered
        @bucket.should_receive(:save).ordered
        @worker.perform_task(@bucket)
      end

      it "should perform the after_each_bucket tasks even if a before_each_bucket task failed" do
        @worker.should_receive(:perform_rake_task).with('git path', "bt_1", @logs).and_return false
        @worker.should_receive(:perform_rake_task).with('git path', 'at_1', @logs)
        @worker.should_receive(:perform_rake_task).with('git path', 'at_2', @logs)
        @worker.perform_task(@bucket)
      end

      it "should perform the after_each_bucket tasks even if a bucket task failed" do
        @worker.should_receive(:perform_rake_task).with('git path', "rt21", @logs).and_return false
        @worker.should_receive(:perform_rake_task).with('git path', 'at_1', @logs)
        @worker.should_receive(:perform_rake_task).with('git path', 'at_2', @logs)
        @worker.perform_task(@bucket)
      end

      it "should set the state to failed when processing an after_each_bucket task fails" do
        @worker.should_receive(:perform_rake_task).with('git path', "at_1", @logs).and_return false
        @bucket.should_receive(:status=).with(40).ordered
        @bucket.should_receive(:save).ordered
        @worker.perform_task(@bucket)
      end

      it "should store the current time into bucket's finished_at when processing has finished" do
        now = Time.now
        Time.stub(:now).and_return now
        @bucket.should_receive(:finished_at=).with(now).ordered
        @bucket.should_receive(:save).ordered
        @worker.perform_task(@bucket)
      end
    end

    describe "when performing rake task" do
      before do
        @rake = TestRake.new
        Rake.stub(:new).and_return @rake
      end

      after do
        TestRake.cleanup
      end

      it "should perform the rake task in the given path" do
        # „fork“ muss stubbed werden, da die Expectations nicht über Prozessgrenzen hinaus
        # funktionieren.
        @worker.stub(:fork).and_yield.and_return(-13)
        @worker.stub(:exit)
        Process.stub(:waitpid).with(-13, Process::WNOHANG).and_return do
          fork {exit 0}
          Process.wait
        end
        File.stub(:read)

        Rake.should_receive(:new).with('path').and_return @rake
        @rake.should_receive(:rake).with('task')
        @worker.perform_rake_task('path', 'task', nil)
      end

      it "should write the output of a task every few seconds into the db" do
        @logs.should_receive(:create).once.with(:log => "first fünf rake output\n").ordered
        @logs.should_receive(:create).once.with(:log => "€second fünf rake output\n").ordered
        @logs.should_receive(:create).once.with(:log => "€third fünf rake output\n").ordered
        @logs.should_receive(:create).once.with(:log => "€last fünf rake output\n").ordered
        @worker.perform_rake_task('path', 'task', @logs)
      end

      it "should not create a log piece in the db if there is no output" do
        @rake.stub(:rake)
        @logs.should_not_receive(:create)
        @worker.perform_rake_task('path', 'task', @logs)
      end

      it "should return false if rake failed" do
        @rake.stub(:rake).and_raise "rake failure"
        @worker.perform_rake_task('path', 'task', @logs).should be_false
      end

      it "should return true if rake succeeded" do
        @rake.stub(:rake)
        @worker.perform_rake_task('path', 'task', @logs).should be_true
      end
    end
  end
end

describe Worker, "when running as follower with fixtures" do
  fixtures :buckets, :builds

  before do
    @bucket = double('bucket', :logs => [], :name => 'task', :log= => nil, :status= => nil,
        :finished_at= => nil, :save => nil, :build => double('build', :id => 1000,
        :commit => 'commit', :project => double('project', :bucket_tasks => [], :id => 33,
        :before_all_tasks => [], :before_bucket_tasks => [], :after_bucket_tasks => [],
        :before_all_code => nil, :before_each_bucket_group_code => nil,
        :bucket_group => 'default', :last_build => nil,
        :git => double('git', :update => nil, :path => '/nix', :current_commit => nil))))
    @worker = Worker.new('dcc_test', nil, :log_level => ::Logger::ERROR)
    @worker.stub(:execute)
  end

  describe "when build failed" do
    before do
      @bucket.build.project.stub(:bucket_tasks).with('task').and_return(['task'])
      @worker.stub(:perform_rake_task).and_return false
      Mailer.stub(:failure_message).and_return double(deliver: nil)
      @bucket.stub(:build_error_log)
    end

    it "should send an email if build failed" do
      Mailer.should_receive(:failure_message).with(@bucket).
          and_return(message = double)
      message.should_receive(:deliver)
      @worker.perform_task(@bucket)
    end

    it "should build the error log" do
      # build_error_log braucht sowohl log als auch finished_at
      @bucket.should_receive(:log=).ordered
      @bucket.should_receive(:finished_at=).ordered
      @bucket.should_receive(:build_error_log).ordered
      @worker.perform_task(@bucket)
    end
  end

  it "should send no email if build succeeded again" do
    @bucket.build.project.should_receive(:last_build).with(:before_build => @bucket.build).
        and_return Build.find(330)
    Mailer.should_not_receive(:failure_message)
    Mailer.should_not_receive(:fixed_message)
    @worker.perform_task(@bucket)
  end

  it "should send no email if first build ever succeeded" do
    @bucket.build.project.should_receive(:last_build).with(:before_build => @bucket.build).
        and_return nil
    Mailer.should_not_receive(:failure_message)
    Mailer.should_not_receive(:fixed_message)
    @worker.perform_task(@bucket)
  end

  it "should send an email if build was fixed" do
    @bucket.build.project.should_receive(:last_build).with(:before_build => @bucket.build).
        and_return Build.find(332)
    Mailer.should_receive(:fixed_message).with(@bucket).and_return(message = double)
    message.should_receive(:deliver)
    @worker.perform_task(@bucket)
  end
end

describe Worker, "when running as leader" do
  def project_double(name, current_commit, next_build_number)
    m = double(name, :name => name, :wants_build? => false, :current_commit => current_commit,
        :id => "#{name}_id", :builds => [], :dependencies => [],
        :buckets_tasks => {"#{name}1" => "tasks1", "#{name}2" => "tasks2", "#{name}3" => "tasks3"})
    m.should_receive(:next_build_number).at_most(:once).and_return(next_build_number)
    m.stub(:update_state)
    m.stub(:last_system_error=)
    m.stub(:save)
    m.stub(:last_build)
    m
  end

  before do
    @project1 = project_double("p1", "12", 2)
    @project2 = project_double("p2", "34", 4)
    @project3 = project_double("p3", "56", 6)
    @project4 = project_double("p4", "78", 8)
    Project.stub(:find).with(:all).and_return [@project1, @project2, @project3, @project4]
    @leader = Worker.new('dcc_test', nil, :log_level => ::Logger::FATAL)
  end

  shared_examples_for "finishing build" do
    describe "when finishing the last build" do
      before do
        Project.stub(:find).with(:all).and_return [@project1]
        @project1.stub(:last_build).and_return(@last_build = double('b', :finished_at => Time.now))
      end

      it "should clean up dead buckets by calling 'project_in_build?'" do
        @leader.should_receive(:project_in_build?).with(@project1)
        @leader.send(@method_under_test)
      end

      describe "when a project is not in build" do
        before do
          @last_build.stub(:identifier).and_return 'nix'
          @leader.stub(:project_in_build?).with(@project1).and_return false
        end

        it "should set the last build's finished_at to now when it's empty" do
          @last_build.stub(:finished_at).and_return nil
          now = Time.now
          Time.stub(:now).and_return now
          @last_build.should_receive(:finished_at=).with(now).ordered
          @last_build.should_receive(:save).ordered
          @leader.send(@method_under_test)
        end

        it "should not change the last build's finished_at when it's already set" do
          @last_build.stub(:finished_at).and_return Time.now
          @last_build.should_not_receive(:finished_at=)
          @last_build.should_not_receive(:save)
          @leader.send(@method_under_test)
        end

        it "should not fail if project was never built" do
          @project1.stub(:last_build).and_return nil
          @leader.send(@method_under_test)
        end
      end

      describe "when a project is in build" do
        before do
          @leader.stub(:project_in_build?).with(@project1).and_return true
        end

        it "should not change the last build's finished_at regardless of it's state" do
          @last_build.should_not_receive(:finished_at=)
          @last_build.should_not_receive(:save)
          @leader.update_buckets
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
      @leader.should_receive(:read_buckets).exactly(4).times.and_return do |p|
        "#{p.name}_buckets"
      end
      @leader.buckets.should_receive(:set_buckets).with('p1', 'p1_buckets')
      @leader.buckets.should_receive(:set_buckets).with('p2', 'p2_buckets')
      @leader.buckets.should_receive(:set_buckets).with('p3', 'p3_buckets')
      @leader.buckets.should_receive(:set_buckets).with('p4', 'p4_buckets')
      @leader.initialize_buckets
    end
  end

  describe "when updating the buckets" do
    before do
      @method_under_test = :update_buckets
    end

    it_should_behave_like "finishing build"

    it "should read and set for every project which is not actually build" do
      @leader.stub(:project_in_build?).and_return {|p| p.name =~ /p[13]/}

      @leader.should_receive(:read_buckets).exactly(2).times.and_return do |p|
        "new_#{p.name}_buckets"
      end

      @leader.buckets.should_receive(:set_buckets).with('p2', 'new_p2_buckets')
      @leader.buckets.should_receive(:set_buckets).with('p4', 'new_p4_buckets')

      @leader.update_buckets
    end
  end

  describe "when determining if project is being build" do
    before do
      @project = double('project', :name => 'p')
    end

    it "should say yes when there are buckets pending" do
      @leader.buckets.set_buckets 'p', ['buckets']
      @leader.should be_project_in_build(@project)
    end

    describe "when there are no buckets left" do
      before do
        @leader.buckets.set_buckets 'p', []
      end

      it "should say no when there never was a build" do
        @project.stub(:last_build).and_return nil
        @leader.should_not be_project_in_build(@project)
      end

      it "should say no when all buckets are processed" do
        @project.stub(:last_build).and_return(double('b', :buckets => [
          double('b1', :status => 10),
          double('b2', :status => 35),
          double('b3', :status => 40),
        ]))
        @leader.should_not be_project_in_build(@project)
      end

      it "should not matter if the pending buckets array is nil or empty" do
        @project.stub(:last_build)

        @leader.buckets.set_buckets 'p', nil
        @leader.should_not be_project_in_build(@project)

        @leader.buckets.set_buckets 'p', []
        @leader.should_not be_project_in_build(@project)
      end

      shared_examples_for "dead or unreachable workers" do
        before do
          @bucket.stub(:status=)
          @bucket.stub(:save)
          @bucket.stub(:worker_uri).and_return "worker's uri"
        end

        it "should say no" do
          @leader.should_not be_project_in_build(@project)
        end

        it "should set the bucket's status to 'processing_failed'" do
          @bucket.should_receive(:status=).with(35).ordered
          @bucket.should_receive(:save).ordered
          @leader.project_in_build?(@project)
        end
      end

      describe "when buckets are pending" do
        before do
          @project.stub(:last_build).and_return(double('b', :buckets => [
            @bucket = double('b1', :status => 20)
          ]))
        end

        it_should_behave_like "dead or unreachable workers"
      end

      describe "when a bucket is in work" do
        before do
          @project.stub(:last_build).and_return(double('b', :buckets => [
            @bucket = double('b1', :status => 30, :id => 666)
          ]))
          DRbObject.stub(:new).with(nil, "worker's uri").and_return(@worker = double('w'))
        end

        describe "when the worker is alive and processing the bucket in question" do
          before do
            @bucket.stub(:worker_uri).and_return "worker's uri"
            @worker.stub(:processing?).with(666).and_return true
          end

          it "should say yes" do
            @leader.should be_project_in_build(@project)
          end
        end

        describe "when the worker is alive but does not process the bucket in question" do
          before do
            @worker.stub(:processing?).with(666).and_return false
          end

          it_should_behave_like "dead or unreachable workers"
        end

        describe "when the worker is not reachable" do
          before do
            @worker.stub(:processing?).with(666).and_raise DRb::DRbConnError.new('nix da')
          end

          it_should_behave_like "dead or unreachable workers"
        end
      end
    end
  end

  describe "when reading the buckets" do
    before do
      @project1.builds.stub(:create).and_return(changed_build = double('', :buckets => double('')))
      @project2.builds.stub(:create).and_return(unchanged_build = double('', :buckets => double('')))
      @project1.stub(:wants_build?).and_return true
      @project2.stub(:wants_build?).and_return false
      changed_build.buckets.stub(:create).and_return do |m|
        double(m[:name], :id => "#{m[:name]}_id")
      end
      unchanged_build.buckets.stub(:create).and_return do |m|
        double(m[:name], :id => "#{m[:name]}_id")
      end
      @leader.stub(:uri).and_return "leader's uri"
      Socket.stub(:gethostname).and_return "leader's hostname"
    end

    it "should return changed buckets" do
      buckets = @leader.read_buckets(@project1)
      buckets.size.should == 3
      buckets.should be_include('p11_id')
      buckets.should be_include('p12_id')
      buckets.should be_include('p13_id')
    end

    it "should not return unchanched buckets" do
      @leader.read_buckets(@project2).should be_empty
    end

    it "should update the projects state if buckets were read" do
      @project1.should_receive(:update_state)
      @leader.read_buckets(@project1)
    end

    it "should not update the projects state if buckets were not read" do
      @project2.should_not_receive(:update_state)
      @leader.read_buckets(@project2)
    end

    it "creates the build and the buckets in the db" do
      @project1.builds.should_receive(:create).with(commit: "12", build_number: 2,
          leader_uri: "leader's uri", leader_hostname: "leader's hostname").
          and_return(build = double('', :buckets => double('')))
      [1, 2, 3].each do |task|
        build.buckets.should_receive(:create).with(:name => "p1#{task}", :status => 20).
            and_return(double('', :id => 1))
      end
      @leader.read_buckets(@project1)
    end

    it "should set the error into the database if an error occurs" do
      @leader.stub(:leader_uri)
      @project1.stub(:update_state).and_raise "an error"

      @project1.should_receive(:last_system_error=).with(/reading buckets failed.*an error/m).
          ordered
      @project1.should_receive(:save).ordered

      @leader.read_buckets(@project1)
    end

    it "should set the error into the database even if a LoadError error occurs" do
      @leader.stub(:leader_uri)
      @project1.stub(:update_state).and_raise LoadError.new('nix da')

      @project1.should_receive(:last_system_error=).with(/reading buckets failed.*nix da/m).ordered
      @project1.should_receive(:save).ordered

      @leader.read_buckets(@project1)
    end

    it "should unset the error in the database if no error occurs" do
      @leader.stub(:leader_uri)
      @project1.stub(:update_state)

      @project1.should_receive(:last_system_error=).with(nil).ordered
      @project1.should_receive(:save).ordered

      @leader.read_buckets(@project1)
    end

    it "should not unset the error in the database if an error occurs" do
      @leader.stub(:leader_uri)
      @project1.stub(:update_state).and_raise "an error"

      @project1.should_not_receive(:last_system_error=).with(nil)

      @leader.read_buckets(@project1)
    end
  end

  describe "when delivering buckets" do
    before do
      @bucket = double('bucket', :worker_uri= => nil, :status= => nil, :save => nil, :id => 123,
          :started_at= => nil, :worker_hostname= => nil,
          :build => double('build', :started_at => nil, :started_at= => nil, :save => nil))
      Bucket.stub(:find).with(123).and_return(@bucket)
      @leader.buckets.stub(:next_bucket).and_return(123)
      @leader.stub(:sleep_until_next_bucket_time).and_return(0)
    end

    it "should deliver the next bucket from the bucket store" do
      Bucket.stub(:find).with("next bucket").and_return(@bucket)

      @leader.buckets.should_receive(:next_bucket).and_return("next bucket")
      @leader.should_receive(:sleep_until_next_bucket_time).and_return(666)
      @leader.next_bucket("requestor", {}).should == ["next bucket", 666]
    end

    it "should store the requestor's uri into the bucket" do
      @bucket.should_receive(:worker_uri=).with("requestor").ordered
      @bucket.should_receive(:save).ordered
      @leader.next_bucket("requestor", {})
    end

    it "should store the status 'in work' into the bucket" do
      @bucket.should_receive(:status=).with(30).ordered
      @bucket.should_receive(:save).ordered
      @leader.next_bucket("requestor", {})
    end

    it "should store the current time for started_at into the bucket" do
      started_at = Time.now
      Time.stub(:now).and_return(started_at)
      @bucket.should_receive(:started_at=).with(started_at).ordered
      @bucket.should_receive(:save).ordered
      @leader.next_bucket("requestor", {})
    end

    it "should store the current time for started_at into the build iff it's the first bucket" do
      @bucket.stub(:build).and_return(build = double('build', :started_at => nil))
      started_at = Time.now
      Time.stub(:now).and_return(started_at)
      build.should_receive(:started_at=).with(started_at).ordered
      build.should_receive(:save).ordered
      @leader.next_bucket("requestor", {})
      build.stub(:started_at).and_return started_at
      @leader.next_bucket("requestor", {})
    end

    it "should store the requestor's hostname into the bucket" do
      @bucket.should_receive(:worker_hostname=).with("requestor's hostname").ordered
      @bucket.should_receive(:save).ordered
      @leader.next_bucket("requestor", {hostname: "requestor's hostname"})
    end

    describe "when no buckets are left" do
      before do
        @leader.buckets.stub(:next_bucket).and_return(nil)
      end

      it "should not try to change bucket" do
        Bucket.should_not_receive(:find)
        @leader.next_bucket("requestor", {})
      end

      it "should deliver the nil bucket" do
        @leader.next_bucket("requestor", {}).should == [nil, 0]
      end
    end
  end
end

end
