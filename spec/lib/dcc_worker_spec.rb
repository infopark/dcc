require File.dirname(__FILE__) + '/../spec_helper'
require 'lib/dcc_worker'
require 'lib/rake'

class DCCWorker
  attr_accessor :buckets
  attr_reader :memcache_client, :uri

  def log_polling_intervall
    return 0.1
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
    File.open(log_file, mode_string="w" ) do |f|
      f.puts "first rake output"
      f.flush
      sleep 0.15
      f.puts "second rake output"
      f.flush
      sleep 0.1
      f.puts "third rake output"
      f.flush
      sleep 0.1
      f.puts "last rake output"
    end
  end
end

describe DCCWorker, "when running as follower" do
  before do
    @worker = DCCWorker.new('dcc_test', nil, :log_level => Logger::ERROR)
    leader = DCCWorker.new('dcc_test', nil, :log_level => Logger::ERROR)
    @worker.stub!(:leader).and_return leader
    leader.stub!(:bucket_request).and_return ["b_id1", 10], ["b_id2", 10], ["b_id3", 10], [nil, 10]
    @worker.memcache_client.stub!(:add)
    @worker.memcache_client.stub!(:get).and_return(leader.uri)
    @worker.stub!(:loop?).and_return true, true, false
    @worker.send(:log).level = Logger::FATAL
    Bucket.stub!(:find)
    Bucket.stub!(:find).with("b_id1").and_return("bucket 1")
    Bucket.stub!(:find).with("b_id2").and_return("bucket 2")
    Bucket.stub!(:find).with("b_id3").and_return("bucket 3")
  end

  it "should perform all tasks given from leader" do
    @worker.should_receive(:perform_task).with("bucket 1")
    @worker.should_receive(:perform_task).with("bucket 2")
    @worker.should_receive(:perform_task).with("bucket 3")
    @worker.run
  end

  describe '' do
    before do
      @git = mock('git', :path => 'git path', :update => nil)
      @project = mock('project', :name => "project's name", :before_build_tasks => %w(bb_1 bb_2),
          :tasks => {"t1" => ["rt1"], "t2" => ["rt21", "rt22"]}, :git => @git,
          :e_mail_receivers => [], :before_task_tasks => %w(bt_1 bt_2))
      @logs = [mock('l1', :log => 'log1'), mock('l2', :log => 'log2')]
      @bucket = mock('bucket', :name => "t2", :log= => nil,
          :build => mock('build', :id => 123, :identifier => 'the commit.666', :project_id => '1',
          :project => @project, :commit => 'the commit', :build_number => 666),
          :save => nil, :logs => @logs, :status= => nil, :log => "nothing to say here")
      @worker.stub!(:last_handled_build).and_return(123)
    end

    describe "when performing task" do
      before do
        @worker.stub!(:perform_rake_task).and_return(true)
      end

      describe "of already handled build" do
        before do
          @worker.stub!(:last_handled_build).and_return(123)
        end

        it "should not perform the before_build rake tasks" do
          @worker.should_not_receive(:perform_rake_task).with('git path', 'bb_1', @logs)
          @worker.should_not_receive(:perform_rake_task).with('git path', 'bb_2', @logs)
          @worker.perform_task(@bucket)
        end
      end

      describe "of build which is handled for the first time" do
        before do
          @worker.stub!(:last_handled_build).and_return(321)
        end

        it "should perform the before_build rake tasks prior to the task's rake tasks" do
          @git.should_receive(:update).ordered
          @worker.should_receive(:perform_rake_task).with('git path', 'bb_1', @logs).ordered
          @worker.should_receive(:perform_rake_task).with('git path', 'bb_2', @logs).ordered
          @worker.should_receive(:perform_rake_task).with('git path', 'bt_1', @logs).ordered
          @worker.perform_task(@bucket)
        end

        it "should set the state to failed when processing of a before_build rake task failed" do
          @worker.should_receive(:perform_rake_task).with('git path', 'bb_1', @logs).
              and_return(false)
          @bucket.should_receive(:status=).with(40).ordered
          @bucket.should_receive(:save).ordered
          @worker.perform_task(@bucket)
        end

        it "should set the last build to the current build's id" do
          @bucket.build.stub!(:id).and_return(666)
          @worker.should_receive(:last_handled_build=).with(666)
          @worker.perform_task(@bucket)
        end
      end

      it "should perform all the rake tasks for the task one by one on the updated git path" do
        @git.should_receive(:update).ordered
        @worker.should_receive(:perform_rake_task).with('git path', 'bt_1', @logs).ordered
        @worker.should_receive(:perform_rake_task).with('git path', 'bt_2', @logs).ordered
        @worker.should_receive(:perform_rake_task).with('git path', 'rt21', @logs).ordered
        @worker.should_receive(:perform_rake_task).with('git path', 'rt22', @logs).ordered
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
    end

    describe "when performing rake task" do
      before do
        @rake = TestRake.new
        Rake.stub!(:new).and_return @rake
      end

      after do
        TestRake.cleanup
      end

# FIXME 'rake.rake task' wird in einem Fork gefahren. Liegt es daran, daß der rake-Aufruf nicht
# expected werden kann?
#      it "should perform the rake task in the given path" do
#        File.stub!(:read)
#        Rake.should_receive(:new).with('path').and_return @rake
#        @rake.should_receive(:rake).with('task')
#        @worker.perform_rake_task('path', 'task', nil)
#      end

      it "should write the output of a task every few seconds into the db" do
        @logs.should_receive(:create).with(:log => "first rake output\n").ordered
        @logs.should_receive(:create).with(:log => "second rake output\n").ordered
        @logs.should_receive(:create).with(:log => "third rake output\n").ordered
        @logs.should_receive(:create).with(:log => "last rake output\n").ordered
        @worker.perform_rake_task('path', 'task', @logs)
      end

      it "should not create a log piece in the db if there is no output" do
        @rake.stub!(:rake)
        @logs.should_not_receive(:create)
        @worker.perform_rake_task('path', 'task', @logs)
      end

      it "should return false if rake failed" do
        @rake.stub!(:rake).and_raise "rake failure"
        @worker.perform_rake_task('path', 'task', @logs).should be_false
      end

      it "should return true if rake succeeded" do
        @rake.stub!(:rake)
        @worker.perform_rake_task('path', 'task', @logs).should be_true
      end
    end
  end
end

describe DCCWorker, "when running as follower with fixtures" do
  fixtures :buckets

  before do
    @bucket = mock('bucket', :logs => [], :name => 'task', :log= => nil, :status= => nil,
        :save => nil, :build => mock('build', :id => 1000, :project_id => 33,
        :project => mock('project', :tasks => {'task' => []}, :before_build_tasks => [],
        :before_task_tasks => [], :git => mock('git', :update => nil, :path => nil))))
    @worker = DCCWorker.new('dcc_test', nil, :log_level => Logger::ERROR)
  end

  it "should send an email if build failed" do
    @bucket.build.project.stub!(:tasks).and_return({'task' => ['task']})
    @bucket.build.project.git.stub!(:path)
    @worker.stub!(:perform_rake_task).and_return false
    Mailer.should_receive(:deliver_failure_message).with(@bucket, %r(^druby://))
    @worker.perform_task(@bucket)
  end

  it "should send no email if build succeeded again" do
    @bucket.build.stub!(:project_id => 300)
    Mailer.should_not_receive(:deliver_failure_message)
    Mailer.should_not_receive(:deliver_fixed_message)
    @worker.perform_task(@bucket)
  end

  it "should send no email if first build ever succeeded" do
    @bucket.build.stub!(:project_id => 3000)
    Mailer.should_not_receive(:deliver_failure_message)
    Mailer.should_not_receive(:deliver_fixed_message)
    @worker.perform_task(@bucket)
  end

  it "should send an email if build was fixed" do
    Mailer.should_receive(:deliver_fixed_message).with(@bucket, %r(^druby://))
    @worker.perform_task(@bucket)
  end
end

describe DCCWorker, "when running as leader" do
  def project_mock(name, build_requested, current_commit, next_build_number)
    m = mock(name, :build_requested? => build_requested, :last_commit => "123",
        :current_commit => current_commit, :url => "#{name}_url", :branch => "#{name}_branch",
        :tasks => {"#{name}1" => "tasks1", "#{name}2" => "tasks2", "#{name}3" => "tasks3"},
        :id => "#{name}_id", :builds => [])
    m.should_receive(:next_build_number).at_most(:once).and_return(next_build_number)
    m.stub!(:last_commit=)
    m.stub!(:build_requested=)
    m.stub!(:save)
    m
  end

  before do
    @requested_project = project_mock("req", true, "123", 6)
    @unchanged_project = project_mock("unc", false, "123", 1)
    @updated_project = project_mock("upd", false, "456", 1)
    Project.stub!(:find).with(:all).and_return(
        [@requested_project, @unchanged_project, @updated_project])
    @leader = DCCWorker.new('dcc_test', nil, :log_level => Logger::ERROR)
  end

  describe "when initializing the buckets" do
    it "should read and set the buckets from the database" do
      @leader.should_receive(:read_buckets).and_return "buckets from the database"
      @leader.initialize_buckets
      @leader.buckets.should == "buckets from the database"
    end
  end

  describe "when reading the buckets" do
    describe "" do
      before do
        @requested_project.builds.stub!(:create).
            and_return(requested_build = mock('', :buckets => mock('')))
        @updated_project.builds.stub!(:create).
            and_return(updated_build = mock('', :buckets => mock('')))
        @unchanged_project.builds.stub!(:create).
            and_return(unchanged_build = mock('', :buckets => mock('')))
        # Mit stub! gehen return_blocks nicht (stand rspec 1.1.11),
        # daher verwende ich hier should_receive mit at_most(100).
        requested_build.buckets.should_receive(:create).at_most(100).and_return do |m|
          mock(m[:name], :id => "#{m[:name]}_id")
        end
        updated_build.buckets.should_receive(:create).at_most(100).and_return do |m|
          mock(m[:name], :id => "#{m[:name]}_id")
        end
        unchanged_build.buckets.should_receive(:create).at_most(100).and_return do |m|
          mock(m[:name], :id => "#{m[:name]}_id")
        end
      end

      it "should return updated buckets" do
        buckets = @leader.read_buckets
        buckets.should include("upd1_id")
        buckets.should include("upd2_id")
        buckets.should include("upd3_id")
      end

      it "should return requested buckets" do
        buckets = @leader.read_buckets
        buckets.should include("req1_id")
        buckets.should include("req2_id")
        buckets.should include("req3_id")
      end

      it "should not return unchanched buckets" do
        buckets = @leader.read_buckets
        buckets.should_not include("unc1_id")
        buckets.should_not include("unc2_id")
        buckets.should_not include("unc3_id")
      end

      it "should update the projects state" do
        @leader.should_receive(:update_project).with(@requested_project)
        @leader.should_receive(:update_project).with(@updated_project)
        @leader.should_not_receive(:update_project).with(@unchanged_project)
        @leader.read_buckets
      end
    end

    it "creates the buckets in the db" do
      @requested_project.builds.should_receive(:create).with(:commit => "123", :build_number => 6).
          and_return(requested_build = mock('', :buckets => mock('')))
      @updated_project.builds.should_receive(:create).with(:commit => "456", :build_number => 1).
          and_return(updated_build = mock('', :buckets => mock('')))
      [1, 2, 3].each do |task|
        requested_build.buckets.should_receive(:create).with(:name => "req#{task}", :status => 20).
            and_return(mock('', :id => 1))
        updated_build.buckets.should_receive(:create).with(:name => "upd#{task}", :status => 20).
            and_return(mock('', :id => 1))
      end
      @leader.read_buckets
    end
  end

  describe "when updating a project" do
    it "should set the last commit to the current commit and save the project" do
      @updated_project.should_receive(:last_commit=).with("456").ordered
      @updated_project.should_receive(:save).ordered
      @leader.update_project(@updated_project)
    end

    it "should unset the build request flag and save the project" do
      @updated_project.should_receive(:build_requested=).with(false).ordered
      @updated_project.should_receive(:save).ordered
      @leader.update_project(@updated_project)
    end
  end

  describe "when delivering buckets" do
    before do
      module Politics::StaticQueueWorker
        def next_bucket(requestor)
          return mocked_next_bucket
        end
      end
      @bucket = mock('bucket', :worker_uri= => nil, :status= => nil, :save => nil)
      @leader.stub!(:mocked_next_bucket).and_return(@bucket)
    end

    it "should store the requestor's uri into the bucket" do
      @bucket.should_receive(:worker_uri=).with("requestor").ordered
      @bucket.should_receive(:save).ordered
      @leader.next_bucket("requestor")
    end

    it "should store the status 'in work' uri into the bucket" do
      @bucket.should_receive(:status=).with(30).ordered
      @bucket.should_receive(:save).ordered
      @leader.next_bucket("requestor")
    end

    it "should deliver the next bucket" do
      @leader.next_bucket("requestor").should == @bucket
    end
  end
end
