require File.dirname(__FILE__) + '/../spec_helper'
require 'lib/dcc_worker'
require 'lib/rake'

class DCCWorker
  attr_accessor :buckets
  attr_reader :memcache_client

  def cleanup
  end

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


describe DCCWorker do
  before do
    @worker = DCCWorker.new('dcc_test', nil, :log_level => Logger::ERROR)
  end

  describe "when determining the project's last build" do
    before do
      @project = mock('project', :id => 'p_id')
    end

    it "should return nil if project has no builds" do
      Build.stub(:find_last_by_project_id).and_return nil
      @worker.last_build_for_project(@project).should be_nil
    end

    it "should return the last build of the available builds" do
      Build.stub(:find_last_by_project_id).with('p_id', :conditions => nil).
          and_return('last action hero')
      @worker.last_build_for_project(@project).should == 'last action hero'
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
      Mailer.should_receive(:deliver_message).with(
          'admin-e-mail', 'running worker failed', /an error/)
      @worker.run
    end
  end

  describe 'when perform_task fails' do
    before do
      @worker.stub!(:loop?).and_return false
      Bucket.stub!(:find).and_return(@bucket = mock('bucket', :status= => nil, :save => nil,
          :log= => nil, :log => 'old_log'))
      @worker.stub!(:perform_task).and_raise("an error")
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
      @bucket.stub!(:log).and_return nil
      @bucket.should_receive(:log=).with(/.*processing bucket failed.*an error/m).ordered
      @bucket.should_receive(:save).ordered
      @worker.run
    end
  end

  describe '' do
    before do
      @git = mock('git', :path => 'git path', :update => nil)
      @project = mock('project', :name => "project's name", :before_all_tasks => [], :git => @git,
          :e_mail_receivers => [], :before_bucket_tasks => [], :after_bucket_tasks => [], :id => 1)
      @project.stub!(:bucket_tasks).with('t1').and_return(['rt1'])
      @project.stub!(:bucket_tasks).with('t2').and_return(['rt21', 'rt22'])
      @logs = [mock('l1', :log => 'log1'), mock('l2', :log => 'log2')]
      @bucket = mock('bucket', :name => "t2", :log= => nil, :finished_at= => nil,
          :build => mock('build', :id => 123, :identifier => 'the commit.666',
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
        @git.should_receive(:update).with('the commit').ordered
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

      it "should store the current time into bucket's finished_at when processing has finished" do
        now = Time.now
        Time.stub!(:now).and_return now
        @bucket.should_receive(:finished_at=).with(now).ordered
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
  fixtures :buckets, :builds

  before do
    @bucket = mock('bucket', :logs => [], :name => 'task', :log= => nil, :status= => nil,
        :finished_at= => nil, :save => nil, :build => mock('build', :id => 1000,
        :commit => 'commit', :project => mock('project', :bucket_tasks => [], :id => 33,
        :before_all_tasks => [], :before_bucket_tasks => [], :after_bucket_tasks => [],
        :git => mock('git', :update => nil, :path => nil))))
    @worker = DCCWorker.new('dcc_test', nil, :log_level => Logger::ERROR)
  end

  it "should send an email if build failed" do
    @bucket.build.project.stub!(:bucket_tasks).with('task').and_return(['task'])
    @bucket.build.project.git.stub!(:path)
    @worker.stub!(:perform_rake_task).and_return false
    Mailer.should_receive(:deliver_failure_message).with(@bucket, %r(^druby://))
    @worker.perform_task(@bucket)
  end

  it "should send no email if build succeeded again" do
    @bucket.build.project.stub!(:id => 300)
    Mailer.should_not_receive(:deliver_failure_message)
    Mailer.should_not_receive(:deliver_fixed_message)
    @worker.perform_task(@bucket)
  end

  it "should send no email if first build ever succeeded" do
    @bucket.build.project.stub!(:id => 3000)
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
    m.stub!(:last_system_error=)
    m.stub!(:save)
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
    before do
      @leader.buckets.buckets['p1'] = 'p1_buckets'
      @leader.buckets.buckets['p2'] = 'p2_buckets'
      @leader.buckets.buckets['p3'] = 'p3_buckets'
      @leader.buckets.buckets['p4'] = 'p4_buckets'
    end

    it "should read and set for every project which is not actually build" do
      @leader.stub(:project_in_build?).and_return {|p| p.name =~ /p[13]/}

      @leader.should_receive(:read_buckets).exactly(2).times.and_return do |p|
        "new_#{p.name}_buckets"
      end

      @leader.update_buckets

      @leader.buckets.buckets['p1'].should == 'p1_buckets'
      @leader.buckets.buckets['p2'].should == 'new_p2_buckets'
      @leader.buckets.buckets['p3'].should == 'p3_buckets'
      @leader.buckets.buckets['p4'].should == 'new_p4_buckets'
    end

    describe "when a project is not in build" do
      before do
        Project.stub!(:find).with(:all).and_return [@project1]
        @leader.stub(:last_build_for_project).with(@project1).and_return(@last_build = mock('b'))
        @leader.stub(:project_in_build?).with(@project1).and_return false
      end

      it "should set the last build's finished_at to now when it's empty" do
        @last_build.stub(:finished_at)
        now = Time.now
        Time.stub!(:now).and_return now
        @last_build.should_receive(:finished_at=).with(now).ordered
        @last_build.should_receive(:save).ordered
        @leader.update_buckets
      end

      it "should not change the last build's finished_at when it's already set" do
        @last_build.stub(:finished_at).and_return Time.now
        @last_build.should_not_receive(:finished_at=)
        @last_build.should_not_receive(:save)
        @leader.update_buckets
      end

      it "should not fail if project was never built" do
        @leader.stub(:last_build_for_project).with(@project1).and_return nil
        @leader.update_buckets
      end
    end

    describe "when a project is in build" do
      before do
        Project.stub!(:find).with(:all).and_return [@project1]
        @leader.stub(:last_build_for_project).with(@project1).and_return(@last_build = mock('b'))
        @leader.stub(:project_in_build?).with(@project1).and_return true
      end

      it "should not change the last build's finished_at regardless of it's state" do
        @last_build.should_not_receive(:finished_at=)
        @last_build.should_not_receive(:save)
        @leader.update_buckets
      end
    end
  end

  describe "when determining if project is being build" do
    before do
      @project = mock('project', :name => 'p')
    end

    it "should say yes when there are buckets pending" do
      @leader.buckets.buckets['p'] = ['buckets']
      @leader.should be_project_in_build(@project)
    end

    describe "when there are no buckets left" do
      before do
        @leader.buckets.buckets['p'] = []
      end

      it "should say no when there never was a build" do
        @leader.stub(:last_build_for_project).with(@project).and_return nil
        @leader.should_not be_project_in_build(@project)
      end

      it "should say no when all buckets are processed" do
        @leader.stub(:last_build_for_project).with(@project).and_return(mock('b', :buckets => [
          mock('b1', :status => 10),
          mock('b2', :status => 35),
          mock('b3', :status => 40),
        ]))
        @leader.should_not be_project_in_build(@project)
      end

      it "should not matter if the pending buckets array is nil or empty" do
        @leader.stub(:last_build_for_project).with(@project)

        @leader.buckets.buckets['p'] = nil
        @leader.should_not be_project_in_build(@project)

        @leader.buckets.buckets['p'] = []
        @leader.should_not be_project_in_build(@project)
      end

      shared_examples_for "buckets are unprocessed" do
        before do
          @leader.stub(:last_build_for_project).with(@project).and_return(mock('b', :buckets => [
            @bucket = mock('b1', :worker_uri => "worker's uri")
          ]))
          DRbObject.stub(:new).with(nil, "worker's uri").and_return(@worker = mock('w'))
        end

        shared_examples_for "dead or unreachable workers" do
          before do
            @bucket.stub(:status=)
            @bucket.stub(:save)
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

        describe "when the worker is alive" do
          before do
            @worker.stub(:alive?).and_return true
          end

          it "should say yes" do
            @leader.should be_project_in_build(@project)
          end
        end

        describe "when the worker is dead" do
          before do
            @worker.stub(:alive?).and_return false
          end

          it_should_behave_like "dead or unreachable workers"
        end

        describe "when the worker is not reachable" do
          before do
            @worker.stub(:alive?).and_raise DRb::DRbConnError.new('nix da')
          end

          it_should_behave_like "dead or unreachable workers"
        end
      end

      describe "when a pending bucket is assigned to a worker" do
        it_should_behave_like "buckets are unprocessed"

        before do
          @bucket.stub(:status).and_return 20
        end
      end

      describe "when a bucket is in work" do
        it_should_behave_like "buckets are unprocessed"

        before do
          @bucket.stub(:status).and_return 30
        end
      end
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

    it "creates the build and the buckets in the db" do
      @project1.builds.should_receive(:create).
          with(:commit => "12", :build_number => 2, :leader_uri => "leader's uri").
          and_return(build = mock('', :buckets => mock('')))
      [1, 2, 3].each do |task|
        build.buckets.should_receive(:create).with(:name => "p1#{task}", :status => 20).
            and_return(mock('', :id => 1))
      end
      @leader.read_buckets(@project1)
    end

    it "should set the error into the database if an error occurs" do
      @leader.stub!(:leader_uri)
      @project1.stub!(:update_state).and_raise "an error"

      @project1.should_receive(:last_system_error=).with(/reading buckets failed.*an error/m).
          ordered
      @project1.should_receive(:save).ordered

      @leader.read_buckets(@project1)
    end

    it "should set the error into the database even if a LoadError error occurs" do
      @leader.stub!(:leader_uri)
      @project1.stub!(:update_state).and_raise LoadError.new('nix da')

      @project1.should_receive(:last_system_error=).with(/reading buckets failed.*nix da/m).ordered
      @project1.should_receive(:save).ordered

      @leader.read_buckets(@project1)
    end

    it "should unset the error in the database if no error occurs" do
      @leader.stub!(:leader_uri)
      @project1.stub!(:update_state)

      @project1.should_receive(:last_system_error=).with(nil).ordered
      @project1.should_receive(:save).ordered

      @leader.read_buckets(@project1)
    end

    it "should not unset the error in the database if an error occurs" do
      @leader.stub!(:leader_uri)
      @project1.stub!(:update_state).and_raise "an error"

      @project1.should_not_receive(:last_system_error=).with(nil)

      @leader.read_buckets(@project1)
    end
  end

  describe "when delivering buckets" do
    before do
      @bucket = mock('bucket', :worker_uri= => nil, :status= => nil, :save => nil, :id => 123,
          :started_at= => nil,
          :build => mock('build', :started_at => nil, :started_at= => nil, :save => nil))
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

    it "should store the current time for started_at into the bucket" do
      started_at = Time.now
      Time.stub!(:now).and_return(started_at)
      @bucket.should_receive(:started_at=).with(started_at).ordered
      @bucket.should_receive(:save).ordered
      @leader.next_bucket("requestor")
    end

    it "should store the current time for started_at into the build iff it's the first bucket" do
      @bucket.stub!(:build).and_return(build = mock('build', :started_at => nil))
      started_at = Time.now
      Time.stub!(:now).and_return(started_at)
      build.should_receive(:started_at=).with(started_at).ordered
      build.should_receive(:save).ordered
      @leader.next_bucket("requestor")
      build.stub!(:started_at).and_return started_at
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
