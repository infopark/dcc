# encoding: utf-8
require File.dirname(__FILE__) + '/../spec_helper'

describe Dependency do
  fixtures :projects, :dependencies

  before do
    @dependency = Dependency.find(1)
  end

  it "should have a project" do
    expect(@dependency.project).not_to be_nil
  end

  it "should have an url" do
    expect(@dependency.url).to eq("url1")
  end

  it "should have a branch" do
    expect(@dependency.branch).to eq("branch1")
  end

  it "may have a fallback branch" do
    expect(@dependency.fallback_branch).to be_nil
    expect(Dependency.find(2).fallback_branch).to eq("branch3")
  end

  it "should have a last_commit" do
    expect(@dependency.last_commit).to eq("old")
  end
end

describe Dependency do
  before do
    @dependency = Dependency.new(:url => "url", :branch => "b", :fallback_branch => "fb")
    allow(@dependency).to receive(:project).and_return double('project', :name => "project's name", :id => 123)
  end

  describe "when providing git" do
    it "should create a new dependency git using url, branch, fallback_branch and project's name" do
      expect(DCC::Git).to receive(:new).with("project's name", 123, "url", "b", "fb", true).
          and_return "the git"
      expect(@dependency.git).to eq("the git")
    end

    it "should reuse an already created git" do
      expect(DCC::Git).to receive(:new).once.and_return "the git"
      expect(@dependency.git).to eq("the git")
      expect(@dependency.git).to eq("the git")
      expect(@dependency.git).to eq("the git")
    end
  end

  describe "with git" do
    before do
      git = double("git", :current_commit => "the current commit", :path => 'git_path')
      allow(@dependency).to receive(:git).and_return git
    end

    describe "when providing current commit" do
      it "should get and return the current commit" do
        expect(@dependency.current_commit).to eq("the current commit")
      end
    end

    describe "when asked 'has_changed?'" do
      before do
        allow(@dependency).to receive(:last_commit).and_return 'the current commit'
        allow(@dependency.git).to receive(:update)
      end

      it "should answer 'true' if current commit has changed" do
        allow(@dependency).to receive(:current_commit).and_return 'new'
        expect(@dependency.has_changed?).to be_truthy
      end

      it "should answer 'false' if current commit has not changed" do
        expect(@dependency.has_changed?).to be_falsey
      end

      it "should update the repository prior to asking for the current commit" do
        expect(@dependency.git).to receive(:update).ordered
        expect(@dependency.git).to receive(:current_commit).ordered
        @dependency.has_changed?
      end
    end
  end

  describe "when updating state" do
    it "should set last commit to current commit and save" do
      allow(@dependency).to receive(:current_commit).and_return 'new'
      expect(@dependency).to receive(:last_commit=).with('new').ordered
      expect(@dependency).to receive(:save).ordered
      @dependency.update_state
    end
  end
end
