require File.dirname(__FILE__) + '/../spec_helper'
require 'lib/dcc_worker'
require 'lib/rake'

class DCCWorker
  attr_accessor :buckets
  attr_reader :memcache_client

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

  describe 'when even the basic things (process_bucket) fail' do
    before do
      @worker.stub!(:process_bucket).and_raise("an error")
    end

    it "should send an email to the admin" do
      @worker.stub!(:admin_e_mail_address).and_return('admin-e-mail')
      Mailer.should_receive(:send).with(:deliver_message,
          'admin-e-mail', 'running worker failed', /an error/)
      @worker.run
    end
  end

  describe 'when perform_task fails' do
    before do
      @worker.stub!(:loop?).and_return false
      Bucket.stub!(:find).and_return(@bucket = mock('bucket', :status= => nil, :save => nil))
      @worker.stub!(:perform_task).and_raise("an error")
    end

    it "should set bucket's status to 'processing failed'" do
      @bucket.should_receive(:status=).with(35).ordered
      @bucket.should_receive(:save).ordered
      @worker.run
    end

    it "should send a 'bucket message' email to the admin" do
      @worker.stub!(:admin_e_mail_address).and_return('admin-e-mail')
      Mailer.should_receive(:send).with(:deliver_bucket_message,
          @bucket, 'admin-e-mail', 'processing bucket failed', /an error/)
      @worker.run
    end
  end

  describe '' do
    before do
      @git = mock('git', :path => 'git path', :update => nil)
      @project = mock('project', :name => "project's name", :before_all_tasks => [],
          :buckets_tasks => {"t1" => ["rt1"], "t2" => ["rt21", "rt22"]}, :git => @git,
          :e_mail_receivers => [], :before_bucket_tasks => [], :after_bucket_tasks => [])
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
        @project.stub!(:before_all_tasks).with("t2").and_return %w(bb_1 bb_2)
        @project.stub!(:before_bucket_tasks).with("t2").and_return %w(bt_1 bt_2)
        @project.stub!(:after_bucket_tasks).with("t2").and_return %w(at_1 at_2)
      end

      describe "of already handled build" do
        before do
          @worker.stub!(:last_handled_build).and_return(123)
        end

        it "should not perform the before_all rake tasks" do
          @worker.should_not_receive(:perform_rake_task).with('git path', 'bb_1', @logs)
          @worker.should_not_receive(:perform_rake_task).with('git path', 'bb_2', @logs)
          @worker.perform_task(@bucket)
        end
      end

      describe "of build which is handled for the first time" do
        before do
          @worker.stub!(:last_handled_build).and_return(321)
        end

        it "should perform the before_all rake tasks prior to the task's rake tasks" do
          @git.should_receive(:update).ordered
          @worker.should_receive(:perform_rake_task).with('git path', 'bb_1', @logs).ordered
          @worker.should_receive(:perform_rake_task).with('git path', 'bb_2', @logs).ordered
          @worker.should_receive(:perform_rake_task).with('git path', 'bt_1', @logs).ordered
          @worker.perform_task(@bucket)
        end

        it "should set the state to failed when processing of a before_all rake task failed" do
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

        it "should not perform the after_each_bucket tasks if a before_all task failed" do
          @worker.should_receive(:perform_rake_task).with('git path', "bb_1", @logs).
              and_return false
          @worker.should_not_receive(:perform_rake_task).with('git path', 'at_1', @logs)
          @worker.should_not_receive(:perform_rake_task).with('git path', 'at_2', @logs)
          @worker.perform_task(@bucket)
        end
      end

      it "should perform all the rake tasks for the task one by one on the updated git path" do
        @git.should_receive(:update).ordered
        @worker.should_receive(:perform_rake_task).with('git path', 'bt_1', @logs).ordered
        @worker.should_receive(:perform_rake_task).with('git path', 'bt_2', @logs).ordered
        @worker.should_receive(:perform_rake_task).with('git path', 'rt21', @logs).ordered
        @worker.should_receive(:perform_rake_task).with('git path', 'rt22', @logs).ordered
        @worker.should_receive(:perform_rake_task).with('git path', 'at_1', @logs).ordered
        @worker.should_receive(:perform_rake_task).with('git path', 'at_2', @logs).ordered
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
        :project => mock('project', :buckets_tasks => {'task' => []}, :before_all_tasks => [],
        :before_bucket_tasks => [], :after_bucket_tasks => [],
        :git => mock('git', :update => nil, :path => nil))))
    @worker = DCCWorker.new('dcc_test', nil, :log_level => Logger::ERROR)
  end

  it "should send an email if build failed" do
    @bucket.build.project.stub!(:buckets_tasks).and_return({'task' => ['task']})
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
  def project_mock(name, current_commit, next_build_number)
    m = mock(name, :name => name, :wants_build? => false, :current_commit => current_commit,
        :id => "#{name}_id", :builds => [], :dependencies => [],
        :buckets_tasks => {"#{name}1" => "tasks1", "#{name}2" => "tasks2", "#{name}3" => "tasks3"})
    m.should_receive(:next_build_number).at_most(:once).and_return(next_build_number)
    m.stub!(:update_state)
    m
  end

  before do
    @project1 = project_mock("p1", "12", 2)
    @project2 = project_mock("p2", "34", 4)
    @project3 = project_mock("p3", "56", 6)
    @project4 = project_mock("p4", "78", 8)
    Project.stub!(:find).with(:all).and_return [@project1, @project2, @project3, @project4]
    @leader = DCCWorker.new('dcc_test', nil, :log_level => Logger::FATAL)
  end

  describe "when initializing the buckets" do
    it "should read and set the buckets for every project" do
      @leader.should_receive(:read_buckets).exactly(4).times.and_return do |p|
        "#{p.name}_buckets"
      end
      @leader.initialize_buckets
      @leader.buckets.buckets.should == {
            'p1' => 'p1_buckets',
            'p2' => 'p2_buckets',
            'p3' => 'p3_buckets',
            'p4' => 'p4_buckets'
          }
    end
  end

  describe "when updating the buckets" do
    it "should read and set for every project which is not actually build" do
      @leader.buckets.buckets['p1'] = 'old_p1_buckets'
      @leader.buckets.buckets['p2'] = []
      @leader.buckets.buckets['p3'] = 'old_p3_buckets'

      @leader.should_receive(:read_buckets).exactly(2).times.and_return do |p|
        "#{p.name}_buckets"
      end
      @leader.update_buckets

      @leader.buckets.buckets['p1'].should == 'old_p1_buckets'
      @leader.buckets.buckets['p2'].should == 'p2_buckets'
      @leader.buckets.buckets['p3'].should == 'old_p3_buckets'
      @leader.buckets.buckets['p4'].should == 'p4_buckets'
    end
  end

  describe "when reading the buckets" do
    before do
      @project1.builds.stub!(:create).and_return(changed_build = mock('', :buckets => mock('')))
      @project2.builds.stub!(:create).and_return(unchanged_build = mock('', :buckets => mock('')))
      @project1.stub!(:wants_build?).and_return true
      @project2.stub!(:wants_build?).and_return false
      changed_build.buckets.stub!(:create).and_return do |m|
        mock(m[:name], :id => "#{m[:name]}_id")
      end
      unchanged_build.buckets.stub!(:create).and_return do |m|
        mock(m[:name], :id => "#{m[:name]}_id")
      end
      @leader.stub!(:uri).and_return "leader's uri"
    end

    it "should return changed buckets" do
      @leader.read_buckets(@project1).should == %w(p11_id p12_id p13_id)
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

    it "creates the buckets in the db" do
      @project1.builds.should_receive(:create).
          with(:commit => "12", :build_number => 2, :leader_uri => "leader's uri").
          and_return(build = mock('', :buckets => mock('')))
      [1, 2, 3].each do |task|
        build.buckets.should_receive(:create).with(:name => "p1#{task}", :status => 20).
            and_return(mock('', :id => 1))
      end
      @leader.read_buckets(@project1)
    end

    it "should send a 'project message' email to the admin if an error occurs" do
      @project1.stub!(:update_state).and_raise "an error"
      @leader.stub!(:admin_e_mail_address).and_return('admin-e-mail')
      Mailer.should_receive(:send).with(:deliver_project_message,
          @project1, 'admin-e-mail', 'reading buckets failed', /an error/)
      @leader.read_buckets(@project1)
    end
  end

  describe "when delivering buckets" do
    before do
      @bucket = mock('bucket', :worker_uri= => nil, :status= => nil, :save => nil, :id => 123)
      Bucket.stub!(:find).with(123).and_return(@bucket)
      @leader.buckets.stub!(:next_bucket).and_return(123)
      @leader.stub!(:sleep_until_next_bucket_time).and_return(0)
    end

    it "should deliver the next bucket from the bucket store" do
      Bucket.stub!(:find).with("next bucket").and_return(@bucket)

      @leader.buckets.should_receive(:next_bucket).and_return("next bucket")
      @leader.should_receive(:sleep_until_next_bucket_time).and_return(666)
      @leader.next_bucket("requestor").should == ["next bucket", 666]
    end

    it "should store the requestor's uri into the bucket" do
      @bucket.should_receive(:worker_uri=).with("requestor").ordered
      @bucket.should_receive(:save).ordered
      @leader.next_bucket("requestor")
    end

    it "should store the status 'in work' into the bucket" do
      @bucket.should_receive(:status=).with(30).ordered
      @bucket.should_receive(:save).ordered
      @leader.next_bucket("requestor")
    end

    describe "when no buckets are left" do
      before do
        @leader.buckets.stub!(:next_bucket).and_return(nil)
      end

      it "should not try to change bucket" do
        Bucket.should_not_receive(:find)
        @leader.next_bucket("requestor")
      end

      it "should deliver the nil bucket" do
        @leader.next_bucket("requestor").should == [nil, 0]
      end
    end
  end
end
