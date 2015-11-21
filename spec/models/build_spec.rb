# encoding: utf-8
require File.dirname(__FILE__) + '/../spec_helper'

describe Build do
  fixtures :projects, :builds, :buckets

  before do
    @build = Build.find(1)
  end

  it "should have a project" do
    expect(@build.project).not_to be_nil
  end

  it "should have a commit" do
    expect(@build.commit).to eq("c1")
  end

  it "should have a build_number" do
    expect(@build.build_number).to eq(6)
  end

  it "should have a leader_uri" do
    expect(@build.leader_uri).to eq("leader's uri")
  end

  it "may have buckets" do
    expect(@build.buckets).to be_empty
    expect(Build.find(3).buckets).not_to be_empty
  end

  it "has an identifier consisting of commit and build_number" do
    expect(@build.identifier).to eq("c1.6")
  end

  it "may have a start time" do
    expect(@build.started_at).to be_nil
    expect(Build.find(3).started_at).to be_a(Time)
  end

  it "may have an end time" do
    expect(@build.finished_at).to be_nil
    expect(Build.find(3).finished_at).to be_a(Time)
  end

  describe "#as_json" do
    it "returns the build as json serializable structure" do
      expect(@build.as_json.with_indifferent_access).to eq({
        id: 1,
        identifier: "c1.6",
        short_identifier: "c1.6",
        status: nil,
        bucket_state_counts: {"10" => 0, "20" => 0, "30" => 0, "35" => 0, "40" => 0},
        started_at: nil,
        finished_at: nil,
        leader_uri: "leader's uri",
        leader_hostname: "leader's hostname",
        commit: "c1",
        gitweb_url: nil,
        failed_buckets: [],
        pending_buckets: [],
        in_work_buckets: [],
        done_buckets: []
      }.with_indifferent_access)
    end
  end
end

