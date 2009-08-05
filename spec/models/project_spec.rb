require File.dirname(__FILE__) + '/../spec_helper'

describe Project do
  fixtures :projects, :builds, :dependencies

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

  it "may have dependencies" do
    @project.dependencies.should be_empty
    Project.find(3).dependencies.should_not be_empty
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
              depends_upon.project "dependency"
              before_all.performs_rake_tasks 'before_all'
              set_gitweb_base_url "gitweb-url"

              buckets "default" do
                before_all.performs_rake_tasks 'before_all_2'
                before_each_bucket.performs_rake_tasks 'before_each'
                after_each_bucket.performs_rake_tasks 'after_each'
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

      it "should provide the gitweb base url" do
        @project.gitweb_base_url.should == "gitweb-url"
      end

      describe "when providing the before_all tasks" do
        it "should return an empty array if no before_all tasks are configured" do
          File.stub!(:read).with("git_path/dcc_config.rb").and_return("")
          @project.before_all_tasks("default:bucket").should == []
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(
              "before_all.performs_rake_tasks")
          @project.before_all_tasks("default:bucket").should == []
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(%Q|
                buckets :default do
                  before_all.performs_rake_tasks
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end
              |)
          @project.before_all_tasks("default:bucket").should == []
        end

        it "should return the configured tasks" do
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(%Q|
                before_all.performs_rake_tasks %w(task_one task_two)
                buckets :default do
                  before_all.performs_rake_tasks %w(task_three task_four)
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end
              |)
          @project.before_all_tasks("default:bucket").should ==
              %w(task_one task_two task_three task_four)
        end

        it "should not return the configured tasks of another bunch of buckets" do
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(%Q|
                buckets :default do
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end

                buckets :other do
                  before_all.performs_rake_tasks %w(task_one task_two)
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end
              |)
          @project.before_all_tasks("default:bucket").should == []
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

      describe "when updating the dependencies" do
        before do
          @project.save
        end

        after do
          @project.delete
        end

        it "should set no dependencies if no build triggering projects are configured" do
          File.stub!(:read).with("git_path/dcc_config.rb").and_return("")
          @project.dependencies.should == []
          File.stub!(:read).with("git_path/dcc_config.rb").and_return("depends_upon")
          @project.dependencies.should == []
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon do
                end
              |)
          @project.update_dependencies
          @project.dependencies.should == []
        end

        it "should set the configured dependencies" do
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1"
                depends_upon.project "url2"
                depends_upon do
                  project "url3"
                  project "url4"
                end
              |)
          @project.update_dependencies
          @project.dependencies.map {|d| d.url}.should == %w(url1 url2 url3 url4)
        end

        it "should set the branch into the dependencies if given" do
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1", :branch => "branch1"
                depends_upon do
                  project "url2", :branch => "branch2"
                end
              |)
          @project.update_dependencies
          @project.dependencies.map {|d| d.branch}.should == %w(branch1 branch2)
        end

        it "should use the projects branch as default of the dependencies' branch" do
          @project.stub!(:branch).and_return "current"
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1"
                depends_upon do
                  project "url2"
                end
              |)
          @project.update_dependencies
          @project.dependencies.map {|d| d.branch}.should == %w(current current)
        end

        it "should update changed dependencies" do
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1", :branch => "branch1"
              |)
          @project.update_dependencies
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1", :branch => "branch2"
              |)
          @project.update_dependencies
          @project.dependencies.map {|d| d.branch}.should == %w(branch2)
        end

        it "should delete removed dependencies" do
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1", :branch => "branch1"
              |)
          @project.update_dependencies
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url2", :branch => "branch1"
              |)
          @project.update_dependencies
          @project.dependencies.map {|d| d.url}.should == %w(url2)
        end

        it "should keep untouched dependencies" do
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1", :branch => "branch1"
              |)
          @project.update_dependencies
          File.stub!(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1", :branch => "branch1"
              |)
          @project.update_dependencies
          @project.dependencies.map {|d| d.branch}.should == %w(branch1)
          @project.dependencies.map {|d| d.url}.should == %w(url1)
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

  describe "when updating the state" do
    before do
      @project.stub!(:current_commit).and_return("456")
      @project.stub!(:dependencies).and_return []
      @project.stub!(:last_commit=)
      @project.stub!(:build_requested=)
      @project.stub!(:save)
    end

    it "should set the last commit to the current commit and save the project" do
      @project.should_receive(:last_commit=).with("456").ordered
      @project.should_receive(:save).ordered
      @project.update_state
    end

    it "should unset the build request flag and save the project" do
      @project.should_receive(:build_requested=).with(false).ordered
      @project.should_receive(:save).ordered
      @project.update_state
    end

    it "should update the last commit of all dependencies and save them" do
      @project.stub!(:dependencies).and_return [dep1 = mock(''), dep2 = mock('')]
      dep1.should_receive(:update_state)
      dep2.should_receive(:update_state)
      @project.update_state
    end
  end

  describe "when being asked if wants_build?" do
    before do
      @project.stub!(:build_requested?).and_return false
      @project.stub!(:current_commit).and_return 'old'
      @project.stub!(:last_commit).and_return 'old'
      @project.stub!(:dependencies).and_return [
            @dep1 = mock('', :has_changed? => false),
            @dep2 = mock('', :has_changed? => false)
          ]
      @project.stub!(:update_dependencies)
    end

    it "should say 'true' if the current commit has changed" do
      @project.stub!(:current_commit).and_return 'new'
      @project.wants_build?.should be_true
    end

    it "should say 'true' if the 'build_requested' flag is set" do
      @project.stub!(:build_requested?).and_return true
      @project.wants_build?.should be_true
    end

    it "should say 'true' if a dependency has changed" do
      @dep2.stub!(:has_changed?).and_return true
      @project.wants_build?.should be_true
    end

    it "should say 'false' else" do
      @project.wants_build?.should be_false
    end

    it "should update the dependencies prior to getting them" do
      @project.should_receive(:update_dependencies).ordered
      @project.should_receive(:dependencies).ordered
      @project.wants_build?
    end
  end

  describe "when providing git_project" do
    it "should deliver the git_project for ssh urls" do
      @project.stub!(:url).and_return("login@machine:project_name.git")
      @project.git_project.should == "project_name.git"
    end

    it "should append .git to ssh url's project name if missing" do
      @project.stub!(:url).and_return("login@machine:project_name")
      @project.git_project.should == "project_name.git"
    end

    it "should deliver the git_project for git+ssh urls" do
      @project.stub!(:url).and_return("git+ssh://machine/project_name.git")
      @project.git_project.should == "project_name.git"
    end

    it "should append .git to git+ssh url's project name if missing" do
      @project.stub!(:url).and_return("git+ssh://machine/project_name")
      @project.git_project.should == "project_name.git"
    end
  end
end
