require File.dirname(__FILE__) + '/../spec_helper'

describe Project do
  fixtures :projects, :buckets

  before(:each) do
    @project = Project.find(1)
  end

  it "should have a name" do
    @project.name.should == "project name"
  end

  it "should have an url" do
    @project.url.should == "project url"
  end

  it "should have a branch" do
    @project.branch.should == "project branch"
  end

  it "may have a last_commit" do
    @project.last_commit.should be_nil
    Project.find(2).last_commit.should == "project's last commit"
  end

  it "may have the build_requested flag set" do
    @project.build_requested.should be_nil
    Project.find(2).build_requested.should be_true
    Project.find(3).build_requested.should be_false
  end

  it "may have buckets" do
    @project.buckets.should be_empty
    Project.find(3).buckets.should_not be_empty
  end
end

describe Project, "when creating a new one" do
  before(:each) do
  end

  it "should raise an error when a project with the given name already exists" do
    Project.new(:name => 'name', :url => 'url', :branch => 'branch').save
    lambda {Project.new(:name => 'name', :url => 'a url', :branch => 'a branch').save}.should\
        raise_error(ActiveRecord::StatementInvalid)
  end

  it "should raise an error when the name was missing" do
    lambda {Project.new(:url => 'url', :branch => 'branch').save}.should raise_error(/blank/)
  end

  it "should raise an error when the name left empty" do
    lambda {Project.new(:name => '', :url => 'url', :branch => 'branch').save}.
        should raise_error(/blank/)
  end

  it "should raise an error when the url was missing" do
    lambda {Project.new(:name => 'name', :branch => 'branch').save}.should raise_error(/blank/)
  end

  it "should raise an error when the url left empty" do
    lambda {Project.new(:url => '', :name => 'name', :branch => 'branch').save}.
        should raise_error(/blank/)
  end

  it "should raise an error when the branch was missing" do
    lambda {Project.new(:url => 'url', :name => 'name').save}.should raise_error(/blank/)
  end

  it "should raise an error when the branch left empty" do
    lambda {Project.new(:branch => '', :url => 'url', :name => 'name').save}.
        should raise_error(/blank/)
  end
end

describe Project do
  before do
    @project = Project.new(:name => "name", :url => "url", :branch => "branch")
  end

  describe "when providing git" do
    it "should create a new git using name, url and branch" do
      Git.should_receive(:new).with("name", "url", "branch").and_return "the git"
      @project.git.should == "the git"
    end

    it "should reuse an already created git" do
      Git.should_receive(:new).once.and_return "the git"
      @project.git.should == "the git"
      @project.git.should == "the git"
      @project.git.should == "the git"
    end
  end

  describe "with git" do
    before do
      git = mock("git", :current_commit => "the current commit", :path => 'git_path')
      @project.stub!(:git).and_return git
    end

    describe "when providing current commit" do
      it "should get and return the current commit" do
        @project.current_commit.should == "the current commit"
      end
    end

    describe "when providing tasks" do
      it "should read the bucket config and return the configured tasks" do
        File.should_receive(:read).with("git_path/dcc.tasks").and_return(%Q|
              ---
              "one":
                - "1a"
                - "1b"
                - "1c"
              "two":
                - "2"
              "three":
                - "3a"
                - "3b"
            |)
        @project.tasks.should == {
              "one" => ["1a", "1b", "1c"],
              "two" => ["2"],
              "three" => ["3a", "3b"]
            }
      end
    end

    it "should compute the next build number by adding one to the highest for the current commit" do
      @project.stub!(:buckets).and_return(buckets = mock('buckets'))
      buckets.stub!(:find).with(:first, :conditions => "'commit' = 'the current commit'",
          :order => "build_number DESC").and_return(mock('bucket', :build_number => 5))

      @project.next_build_number.should == 6
    end

    it "should compute the next build number with 1 for the first build of a commit" do
      @project.stub!(:buckets).and_return(buckets = mock('buckets'))
      buckets.stub!(:find).with(:first, :conditions => "'commit' = 'the current commit'",
          :order => "build_number DESC").and_return nil

      @project.next_build_number.should == 1
    end
  end
end
