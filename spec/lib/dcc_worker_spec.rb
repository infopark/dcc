require File.dirname(__FILE__) + '/../spec_helper'
require 'lib/dcc_worker'

class DCCWorker
  attr_accessor :buckets
  attr_reader :memcache_client, :uri
end

describe DCCWorker, "when running as follower" do
  before do
    @worker = DCCWorker.new(nil, :log_level => Logger::ERROR)
    leader = DCCWorker.new(nil, :log_level => Logger::ERROR)
    @worker.stub!(:leader).and_return leader
    leader.stub!(:bucket_request).and_return [["url1", "branch1", "commit1", "commitno1"], 10],
        [["url2", "branch2", "commit2", "commitno2"], 10],
        [["url3", "branch3", "commit3", "commitno3"], 10],
        [nil, 10]
    @worker.memcache_client.stub!(:add)
    @worker.memcache_client.stub!(:get).and_return(leader.uri)
    @worker.stub!(:loop?).and_return true, true, false
    @worker.send(:log).level = Logger::FATAL
  end

  it "should perform all tasks given from leader" do
    @worker.should_receive(:perform_task).with("url1", "branch1", "commit1", "commitno1")
    @worker.should_receive(:perform_task).with("url2", "branch2", "commit2", "commitno2")
    @worker.should_receive(:perform_task).with("url3", "branch3", "commit3", "commitno3")
    @worker.run
  end
end

describe DCCWorker, "when running as leader" do
  def project_mock(name, build_requested, current_commit, next_build_number)
    m = mock(name, :build_requested? => build_requested, :last_commit => "123",
        :current_commit => current_commit, :url => "#{name}_url", :branch => "#{name}_branch",
        :tasks => %W(#{name}1 #{name}2 #{name}3), :project_id => "#{name}_id")
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
    it "should return updated buckets" do
      buckets = @leader.read_buckets
      buckets.should include(["upd_url", "upd_branch", "456", 1, "upd1"])
      buckets.should include(["upd_url", "upd_branch", "456", 1, "upd2"])
      buckets.should include(["upd_url", "upd_branch", "456", 1, "upd3"])
    end

    it "should return requested buckets" do
      buckets = @leader.read_buckets
      buckets.should include(["req_url", "req_branch", "123", 6, "req1"])
      buckets.should include(["req_url", "req_branch", "123", 6, "req2"])
      buckets.should include(["req_url", "req_branch", "123", 6, "req3"])
    end

    it "should not return unchanched buckets" do
      @leader.read_buckets.map {|b| b[0]}.should_not include("unc_url")
    end

    it "should update the projects state" do
      @leader.should_receive(:update_project).with(@requested_project)
      @leader.should_receive(:update_project).with(@updated_project)
      @leader.should_not_receive(:update_project).with(@unchanged_project)
      @leader.read_buckets
    end

    it "create the buckets in the db" do
      [["req", "123", 6, [1, 2, 3]], ["upd", "456", 1, [1, 2, 3]]].each do |name, commit, n, tasks|
        tasks.each do |task|
          b = mock('bucket')
          Bucket.should_receive(:new).with(:project_id => "#{name}_id", :commit => commit,
              :build_number => n, :name => "#{name}#{task}", :status => 0).and_return b
          b.should_receive(:save)
        end
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
