# encoding: utf-8
require File.dirname(__FILE__) + '/../spec_helper'

describe Dependency do
  fixtures :projects, :dependencies

  before do
    @dependency = Dependency.find(1)
  end

  it "should have a project" do
    @dependency.project.should_not be_nil
  end

  it "should have an url" do
    @dependency.url.should == "url1"
  end

  it "should have a branch" do
    @dependency.branch.should == "branch1"
  end

  it "may have a fallback branch" do
    @dependency.fallback_branch.should be_nil
    Dependency.find(2).fallback_branch.should == "branch3"
  end

  it "should have a last_commit" do
    @dependency.last_commit.should == "old"
  end
end

describe Dependency do
  before do
    @dependency = Dependency.new(:url => "url", :branch => "b", :fallback_branch => "fb")
    @dependency.stub(:project).and_return double('project', :name => "project's name", :id => 123)
  end

  describe "when providing git" do
    it "should create a new dependency git using url, branch, fallback_branch and project's name" do
      DCC::Git.should_receive(:new).with("project's name", 123, "url", "b", "fb", true).
          and_return "the git"
      @dependency.git.should == "the git"
    end

    it "should reuse an already created git" do
      DCC::Git.should_receive(:new).once.and_return "the git"
      @dependency.git.should == "the git"
      @dependency.git.should == "the git"
      @dependency.git.should == "the git"
    end
  end

  describe "with git" do
    before do
      git = double("git", :current_commit => "the current commit", :path => 'git_path')
      @dependency.stub(:git).and_return git
    end

    describe "when providing current commit" do
      it "should get and return the current commit" do
        @dependency.current_commit.should == "the current commit"
      end
    end

    describe "when asked 'has_changed?'" do
      before do
        @dependency.stub(:last_commit).and_return 'the current commit'
        @dependency.git.stub(:update)
      end

      it "should answer 'true' if current commit has changed" do
        @dependency.stub(:current_commit).and_return 'new'
        @dependency.has_changed?.should be_true
      end

      it "should answer 'false' if current commit has not changed" do
        @dependency.has_changed?.should be_false
      end

      it "should update the repository prior to asking for the current commit" do
        @dependency.git.should_receive(:update).ordered
        @dependency.git.should_receive(:current_commit).ordered
        @dependency.has_changed?
      end
    end
  end

  describe "when updating state" do
    it "should set last commit to current commit and save" do
      @dependency.stub(:current_commit).and_return 'new'
      @dependency.should_receive(:last_commit=).with('new').ordered
      @dependency.should_receive(:save).ordered
      @dependency.update_state
    end
  end
end
