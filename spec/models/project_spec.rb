require File.dirname(__FILE__) + '/../spec_helper'

describe Project do
  fixtures :projects, :builds

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

  it "may have builds" do
    @project.builds.should be_empty
    Project.find(3).builds.should_not be_empty
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

    describe "when providing configured information" do
      before do
        File.stub!(:read).with("git_path/dcc_config.rb").and_return(%Q|
              send_notifications_to "to@me.de"
              buckets "default" do
                bucket(:one).performs_rake_tasks %w(1a 1b 1c)
                bucket(:two).performs_rake_tasks "2"
              end

              buckets "extra" do
                bucket(:three).performs_rake_tasks %w(3a 3b)
              end
            |)
      end

      it "should read the config" do
        File.should_receive(:read).with("git_path/dcc_config.rb")
        @project.buckets_tasks
      end

      it "should provide the configured tasks" do
        @project.buckets_tasks.should == {
              "default:one" => ["1a", "1b", "1c"],
              "default:two" => ["2"],
              "extra:three" => ["3a", "3b"]
            }
      end

      describe "when providing the before_all tasks" do
        it "should return an empty array if no before_all tasks are configured" do
          File.stub!(:read).with("git_path/dcc_config.rb").and_return("")
          @project.before_all_tasks.should == []
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(
              "before_all.performs_rake_tasks")
          @project.before_all_tasks.should == []
        end

        it "should return the configured tasks" do
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(
                "before_all.performs_rake_tasks %w(task_one task_two)")
          @project.before_all_tasks.should == %w(task_one task_two)
        end
      end

      describe "when providing the before_each_bucket tasks for a bucket" do
        it "should return an empty array if no before_each_bucket tasks are configured" do
          File.stub!(:read).with("git_path/dcc_config.rb").and_return("")
          @project.before_bucket_tasks("default:bucket").should == []
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(%Q|
                buckets :default do
                  before_each_bucket.performs_rake_tasks
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end
              |)
          @project.before_bucket_tasks("default:bucket").should == []
        end

        it "should not return the configured tasks of another bunch of buckets" do
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(%Q|
                buckets :default do
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end

                buckets :other do
                  before_each_bucket.performs_rake_tasks %w(task_one task_two)
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end
              |)
          @project.before_bucket_tasks("default:bucket").should == []
        end

        it "should return the configured tasks" do
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(%Q|
                buckets :default do
                  before_each_bucket.performs_rake_tasks %w(task_one task_two)
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end
              |)
          @project.before_bucket_tasks("default:bucket").should == %w(task_one task_two)
        end
      end

      describe "when providing the after_each_bucket tasks for a bucket" do
        it "should return an empty array if no after_each_bucket tasks are configured" do
          File.stub!(:read).with("git_path/dcc_config.rb").and_return("")
          @project.after_bucket_tasks("default:bucket").should == []
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(%Q|
                buckets :default do
                  after_each_bucket.performs_rake_tasks
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end
              |)
          @project.after_bucket_tasks("default:bucket").should == []
        end

        it "should not return the configured tasks of another bunch of buckets" do
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(%Q|
                buckets :default do
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end

                buckets :other do
                  after_each_bucket.performs_rake_tasks %w(task_one task_two)
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end
              |)
          @project.after_bucket_tasks("default:bucket").should == []
        end

        it "should return the configured tasks" do
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(%Q|
                buckets :default do
                  after_each_bucket.performs_rake_tasks %w(task_one task_two)
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end
              |)
          @project.after_bucket_tasks("default:bucket").should == %w(task_one task_two)
        end
      end

      describe "when providing the E-Mail addresses" do
        it "should return a single address in an array" do
          @project.e_mail_receivers.should == ['to@me.de']
        end

        it "should return an empty array if no address were specified" do
          File.stub!(:read).with("git_path/dcc_config.rb").and_return("")
          @project.e_mail_receivers.should == []
          File.stub!(:read).with("git_path/dcc_config.rb").and_return("send_notifications_to")
          @project.e_mail_receivers.should == []
        end

        it "should return the specified addresses" do
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(%Q|
                send_notifications_to "to@me.de", "to@me.too"
              |)
          @project.e_mail_receivers.should == ['to@me.de', 'to@me.too']
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(%Q|
                send_notifications_to %w(to@me.de to@me.too)
              |)
          @project.e_mail_receivers.should == ['to@me.de', 'to@me.too']
        end
      end
    end

    it "should compute the next build number by adding one to the highest for the current commit" do
      @project.stub!(:builds).and_return(builds = mock('builds'))
      builds.stub!(:find).with(:first, :conditions => "commit_hash = 'the current commit'",
          :order => "build_number DESC").and_return(mock('build', :build_number => 5))

      @project.next_build_number.should == 6
    end

    it "should compute the next build number with 1 for the first build of a commit" do
      @project.stub!(:builds).and_return(builds = mock('builds'))
      builds.stub!(:find).with(:first, :conditions => "commit_hash = 'the current commit'",
          :order => "build_number DESC").and_return nil

      @project.next_build_number.should == 1
    end
  end
end
