require File.dirname(__FILE__) + '/../spec_helper'
require 'lib/dcc_worker'
require 'lib/rake'

class DCCWorker
  attr_accessor :buckets
  attr_reader :memcache_client, :uri

  def log_polling_intervall
    return 1
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
      sleep 1.5
      f.puts "second rake output"
      f.flush
      sleep 1
      f.puts "third rake output"
      f.flush
      sleep 1
      f.puts "last rake output"
    end
  end
end

describe DCCWorker, "when running as follower" do
  before do
    @worker = DCCWorker.new(nil, :log_level => Logger::ERROR)
    leader = DCCWorker.new(nil, :log_level => Logger::ERROR)
    @worker.stub!(:leader).and_return leader
    leader.stub!(:bucket_request).and_return ["bucket 1", 10], ["bucket 2", 10], ["bucket 3", 10],
        [nil, 10]
    @worker.memcache_client.stub!(:add)
    @worker.memcache_client.stub!(:get).and_return(leader.uri)
    @worker.stub!(:loop?).and_return true, true, false
    @worker.send(:log).level = Logger::FATAL
  end

  it "should perform all tasks given from leader" do
    @worker.should_receive(:perform_task).with("bucket 1")
    @worker.should_receive(:perform_task).with("bucket 2")
    @worker.should_receive(:perform_task).with("bucket 3")
    @worker.run
  end

  describe "when performing task" do
    before do
      @git = mock('git', :path => 'git path', :update => nil)
      project = mock('project', :tasks => {"t1" => ["rt1"], "t2" => ["rt21", "rt22"]}, :git => @git)
      @logs = [mock('l1', :log => 'log1'), mock('l2', :log => 'log2')]
      @bucket = mock('bucket', :project => project, :name => "t2", :log= => nil, :save => nil,
          :logs => @logs, :status= => nil)
    end

    after do
      TestRake.cleanup
    end

    it "should perform the rake tasks for the task one by one on the updated git path" do
      @git.should_receive(:update)
      @worker.should_receive(:perform_rake_task).with('git path', 'rt21', @logs).ordered
      @worker.should_receive(:perform_rake_task).with('git path', 'rt22', @logs).ordered
      @worker.perform_task(@bucket)
    end

    it "should move the logs into the bucket when processing has finished" do
      @worker.stub!(:perform_rake_task)
      @bucket.should_receive(:log=).with("log1log2").ordered
      @bucket.should_receive(:save).ordered
      @logs.should_receive(:clear).ordered
      @worker.perform_task(@bucket)
    end

    it "should set the state to failed when processing the first of two tasks fails" do
      @worker.should_receive(:perform_rake_task).and_return(false, true)
      @bucket.should_receive(:status=).with(2).ordered
      @bucket.should_receive(:save).ordered
      @worker.perform_task(@bucket)
    end

    it "should set the state to failed when processing the second of two tasks fails" do
      @worker.should_receive(:perform_rake_task).and_return(true, false)
      @bucket.should_receive(:status=).with(2).ordered
      @bucket.should_receive(:save).ordered
      @worker.perform_task(@bucket)
    end

    it "should set the state to done when processing has finished successfully" do
      @worker.should_receive(:perform_rake_task).and_return(true, true)
      @bucket.should_receive(:status=).with(1).ordered
      @bucket.should_receive(:save).ordered
      @worker.perform_task(@bucket)
    end

    describe "when performing rake task" do
      before do
        @rake = TestRake.new
        Rake.stub!(:new).and_return @rake
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

describe DCCWorker, "when running as leader" do
  def project_mock(name, build_requested, current_commit, next_build_number)
    m = mock(name, :build_requested? => build_requested, :last_commit => "123",
        :current_commit => current_commit, :url => "#{name}_url", :branch => "#{name}_branch",
        :tasks => {"#{name}1" => "tasks1", "#{name}2" => "tasks2", "#{name}3" => "tasks3"},
        :id => "#{name}_id", :buckets => [])
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
    @leader = DCCWorker.new(nil, :log_level => Logger::ERROR)
  end

  describe "when initializing the buckets" do
    it "should read and set the buckets from the database" do
      @leader.should_receive(:read_buckets).and_return "buckets from the database"
      @leader.initialize_buckets
      @leader.buckets.should == "buckets from the database"
    end
  end

  describe "when reading the buckets" do
    describe do
      before do
        @requested_project.buckets.should_receive(:create).at_most(100).and_return do |m|
          mock(m[:name], :name => m[:name])
        end
        @updated_project.buckets.should_receive(:create).at_most(100).and_return do |m|
          mock(m[:name], :name => m[:name])
        end
      end

      it "should return updated buckets" do
        bucket_names = @leader.read_buckets.map {|b| b.name}
        bucket_names.should include("upd1")
        bucket_names.should include("upd2")
        bucket_names.should include("upd3")
      end

      it "should return requested buckets" do
        bucket_names = @leader.read_buckets.map {|b| b.name}
        bucket_names.should include("req1")
        bucket_names.should include("req2")
        bucket_names.should include("req3")
      end

      it "should not return unchanched buckets" do
        bucket_names = @leader.read_buckets.map {|b| b.name}
        bucket_names.should_not include("unc1")
        bucket_names.should_not include("unc2")
        bucket_names.should_not include("unc3")
      end

      it "should update the projects state" do
        @leader.should_receive(:update_project).with(@requested_project)
        @leader.should_receive(:update_project).with(@updated_project)
        @leader.should_not_receive(:update_project).with(@unchanged_project)
        @leader.read_buckets
      end
    end

    it "create the buckets in the db" do
      [1, 2, 3].each do |task|
        @requested_project.buckets.should_receive(:create).with(:commit => "123",
            :build_number => 6, :name => "req#{task}", :status => 0)
        @updated_project.buckets.should_receive(:create).with(:commit => "456",
            :build_number => 1, :name => "upd#{task}", :status => 0)
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
end
