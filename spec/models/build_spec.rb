# encoding: utf-8
require File.dirname(__FILE__) + '/../spec_helper'

describe Build do
  fixtures :projects, :builds, :buckets

  before do
    @build = Build.find(1)
  end

  it "should have a project" do
    @build.project.should_not be_nil
  end

  it "should have a commit" do
    @build.commit.should == "c1"
  end

  it "should have a build_number" do
    @build.build_number.should == 6
  end

  it "should have a leader_uri" do
    @build.leader_uri.should == "leader's uri"
  end

  it "may have buckets" do
    @build.buckets.should be_empty
    Build.find(3).buckets.should_not be_empty
  end

  it "has an identifier consisting of commit and build_number" do
    @build.identifier.should == "c1.6"
  end

  it "may have a start time" do
    @build.started_at.should be_nil
    Build.find(3).started_at.should be_a(Time)
  end

  it "may have an end time" do
    @build.finished_at.should be_nil
    Build.find(3).finished_at.should be_a(Time)
  end

  describe "#as_json" do
    it "returns the build as json serializable structure" do
      @build.as_json.with_indifferent_access.should == {
        id: 1,
        identifier: "c1.6",
        short_identifier: "c1.6",
        status: nil,
        bucket_state_counts: {"10" => 0, "20" => 0, "30" => 0, "35" => 0, "40" => 0},
        started_at: nil,
        finished_at: nil,
        leader_uri: "leader's uri",
        leader_hostname: nil,
        commit: "c1",
        gitweb_url: nil,
        failed_buckets: [],
        pending_buckets: [],
        in_work_buckets: [],
        done_buckets: []
      }.with_indifferent_access
    end
  end
end

