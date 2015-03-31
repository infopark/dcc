# encoding: utf-8
require 'spec_helper'

describe Project do
  fixtures :projects, :builds, :dependencies, :buckets, :logs

  before(:each) do
    @project = Project.find(1)
  end

  it "should have an id" do
    @project.id.should == 1
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

  it "may have an owner" do
    @project.owner.should be_nil
    Project.find(2).owner.should == "project owner"
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

  it "may have a last_system_error" do
    @project.last_system_error.should be_nil
    Project.find(3).last_system_error.should == "project's last system error"
  end

  context "when deleting" do
    it "deletes itself and all it's builds, buckets and logs" do
      Project.destroy(3)
      lambda {
        Project.find(3)
      }.should raise_error ActiveRecord::RecordNotFound
      [1, 3].each do |id|
        lambda {
          Build.find(id)
        }.should raise_error ActiveRecord::RecordNotFound
      end
      [1, 2].each do |id|
        lambda {
          Bucket.find(id)
        }.should raise_error ActiveRecord::RecordNotFound
      end
      [1, 2].each do |id|
        lambda {
          Log.find(id)
        }.should raise_error ActiveRecord::RecordNotFound
      end
    end

    it "does not delete builds, buckets or logs of other projects" do
      Project.destroy(1)
      lambda {
        Project.find(1)
      }.should raise_error ActiveRecord::RecordNotFound
      [1, 3].each {|id| Build.find(id) }
      [1, 2].each {|id| Bucket.find(id) }
      [1, 2].each {|id| Log.find(id) }
    end
  end

  describe "#as_json" do
    it "returns the project as json serializable structure" do
      @project.as_json.with_indifferent_access.should == {
        name: "project name",
        id: 1,
        url: "project url",
        branch: "project branch",
        build_requested: nil,
        last_build: nil,
        last_system_error: nil,
        owner: nil,
      }.with_indifferent_access
    end
  end
end

describe Project, "when creating a new one" do
  before(:each) do
  end

  it "should raise an error when a project with the given name, branch and owner already exists" do
    # FIXME shclägt grad nicht fehl, weil nil offenbar nicht für uniqueness taugt
    # FIXME Idee: immer leerstring speichern, wenn owner nil und die Spalte auf not_null setzen
    #Project.new(:name => 'name', :url => 'url', :branch => 'branch').save
    #Lambda {Project.new(:name => 'name', :url => 'a url', :branch => 'branch').save}.should\
    #    raise_error(ActiveRecord::StatementInvalid)

    Project.new(name: 'name', url: 'url', branch: 'branch', owner: 'owner').save
    lambda {Project.new(name: 'name', url: 'a url', branch: 'branch', owner: 'owner').save}.should\
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

  describe "when determining" do
    before do
      @project.stub(:id).and_return 'p_id'
    end

    describe "the last build" do
      it "should return nil if it has no builds" do
        @project.last_build.should be_nil
      end

      it "should return the last build of the available builds" do
        @project.stub(:builds).and_return ['predator', 'terminator', 'last action hero']
        @project.last_build.should == 'last action hero'
      end
    end

    describe "the build before another build" do
      it "returns the build before the specified build" do
        @project.stub(:builds).and_return(builds = double('builds'))
        builds.stub(:where).with("id < ?", 12345).and_return(double.tap do |result|
          result.stub(:order).with("id DESC").and_return(
              ['last man standing', 'somewhere in the middle', 'first in a row'])
        end)
        @project.build_before(double(:id => 12345)).should == 'last man standing'
      end
    end
  end

  describe "when providing git" do
    before do
      @project.stub(:id).and_return 123
    end

    it "should create a new git using name, url and branch" do
      DCC::Git.should_receive(:new).with("name", 123, "url", "branch").and_return "the git"
      @project.git.should == "the git"
    end

    it "should reuse an already created git" do
      DCC::Git.should_receive(:new).once.and_return "the git"
      @project.git.should == "the git"
      @project.git.should == "the git"
      @project.git.should == "the git"
    end
  end

  describe "with git" do
    before do
      @git = double("git", :current_commit => "the current commit", :path => 'git_path',
          :remote_changed? => false)
      @project.stub(:git).and_return @git
    end

    describe "when providing current commit" do
      it "should get and return the current commit" do
        @project.current_commit.should == "the current commit"
      end
    end

    describe "when reading the config" do
      it "should read the config only once" do
        File.should_receive(:read).with("git_path/dcc_config.rb").once.and_return ""
        @project.send(:read_config)
        @project.send(:read_config)
      end

      it "should reread the config if git commit changed" do
        @git.stub(:current_commit).and_return('old one')
        File.should_receive(:read).with("git_path/dcc_config.rb").twice.and_return ""
        @project.send(:read_config)
        @git.stub(:current_commit).and_return('new one')
        @project.send(:read_config)
      end
    end

    describe "when being asked if wants_build?" do
      before do
        @project.stub(:build_requested?).and_return false
        @project.stub(:last_commit).and_return 'the current commit'
        @project.stub(:dependencies).and_return [
              @dep1 = double('', :has_changed? => false),
              @dep2 = double('', :has_changed? => false)
            ]
        @project.stub(:update_dependencies)
        @git.stub(:update)
        File.stub(:read).with("git_path/dcc_config.rb").and_return "rebuild_if {false}"
      end

      it "should say 'true' if the current commit is not the same as remote" do
        @git.stub(:remote_changed?).and_return true
        @project.stub(:current_commit).and_return 'new'
        @project.wants_build?.should be_true
      end

      it "should say 'true' if the 'build_requested' flag is set" do
        @project.stub(:build_requested?).and_return true
        @project.wants_build?.should be_true
      end

      it "should say 'true' if a dependency has changed" do
        @dep2.stub(:has_changed?).and_return true
        @project.wants_build?.should be_true
      end

      it "should say 'true' if the 'rebuild_if' block returns 'true'" do
        File.stub(:read).with("git_path/dcc_config.rb").and_return "rebuild_if {true}"
        @project.wants_build?.should be_true
      end

      it "should not crash if no 'rebuild_if' block was given" do
        File.stub(:read).with("git_path/dcc_config.rb").and_return ""
        @project.wants_build?
      end

      it "should say 'false' else" do
        @project.wants_build?.should be_false
      end

      it "should update the dependencies prior to getting them" do
        @project.should_receive(:update_dependencies).ordered
        @project.should_receive(:dependencies).ordered
        @project.wants_build?
      end

      it "should update the repository prior to getting the current commit" do
        @git.stub(:remote_changed?).and_return true
        @git.should_receive(:update).ordered
        @git.should_receive(:current_commit).ordered
        @project.wants_build?
      end
    end

    describe "when providing configured information" do
      before do
        @git.stub(:current_commit).and_return('current commit')
        File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
              send_notifications_to "to@me.de"
              depends_upon.project "dependency"
              before_all.performs_rake_tasks 'before_all'

              before_all do
                "this code is executed even before the before_all rake tasks"
              end

              before_each_bucket_group do
                "this code is executed once for every bucket group"
              end

              buckets "default" do
                before_all.performs_rake_tasks 'before_all_2'
                before_each_bucket.performs_rake_tasks 'before_each'
                after_each_bucket.performs_rake_tasks 'after_each'
                bucket(:one).performs_rake_tasks %w(1a 1b 1c)
                bucket(:two).performs_rake_tasks "2"
              end

              buckets "extra" do
                send_notifications_to "to@you.com"
                bucket(:three).performs_rake_tasks('3a', '3b')
                for_error_log do
                  "extra's error log"
                end
              end

              buckets "nix weita" do
                bucket(:four).performs_rake_tasks('4')
                for_error_log do
                  "nix weita's error log"
                end
              end
            |)
      end

      it "should read the config" do
        File.should_receive(:read).with("git_path/dcc_config.rb").and_return("")
        @project.buckets_tasks
      end

      it "should provide the configured tasks" do
        @project.buckets_tasks.should == {
              "default:one" => ["1a", "1b", "1c"],
              "default:two" => ["2"],
              "extra:three" => ["3a", "3b"],
              "nix weita:four" => ["4"]
            }
      end

      it "should provide the configured tasks for a given bucket" do
        @project.bucket_tasks('default:one').should == ["1a", "1b", "1c"]
        @project.bucket_tasks('huh?').should == []
      end

      it "should provide the bucket group for a given bucket" do
        @project.bucket_group('default:one').should == 'default'
        @project.bucket_group('default:two').should == 'default'
        @project.bucket_group('extra:three').should == 'extra'
        @project.bucket_group('huh?').should be_nil
      end

      describe "when providing the “for_error_log” code for a bucket" do
        it "should return nil when there is no “for_error_log” code" do
          @project.for_error_log("default:one").should be_nil
        end

        it "should return the “for_error_log” code of the bucket group for the bucket" do
          @project.for_error_log("extra:three").call.should == "extra's error log"
          @project.for_error_log("nix weita:four").call.should == "nix weita's error log"
        end
      end

      describe "when providing the before_all tasks" do
        it "should return an empty array if no before_all tasks are configured" do
          File.stub(:read).with("git_path/dcc_config.rb").and_return("")
          @project.before_all_tasks("default:bucket").should == []
          File.stub(:read).with("git_path/dcc_config.rb").and_return(
              "before_all.performs_rake_tasks")
          @project.before_all_tasks("default:bucket").should == []
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
                buckets :default do
                  before_all.performs_rake_tasks
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end
              |)
          @project.before_all_tasks("default:bucket").should == []
        end

        it "should return the configured tasks" do
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
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
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
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

      describe "when providing the before_all_code" do
        it "should return the before_all_code" do
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
                before_all do
                  "before_all_code"
                end
              |)
          @project.before_all_code.should be_a(Proc)
          @project.before_all_code.call.should == "before_all_code"
        end

        it "should return the before_all_code even if before_all was accessed later on without code" do
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
                before_all do
                  "before_all_code"
                end

                before_all.performs_rake_tasks("bla")
              |)
          @project.before_all_code.should be_a(Proc)
          @project.before_all_code.call.should == "before_all_code"
        end

        it "should return nil if no before_all-block was given" do
          File.stub(:read).with("git_path/dcc_config.rb").and_return("")
          @project.before_all_code.should be_nil
          File.stub(:read).with("git_path/dcc_config.rb").and_return("before_all {}")
          @project.before_all_code.should be_nil
        end
      end

      describe "when providing the before_each_bucket_group code" do
        it "should return nil if no before_each_bucket_group code is configured" do
          File.stub(:read).with("git_path/dcc_config.rb").and_return("")
          @project.before_each_bucket_group_code.should be_nil
          File.stub(:read).with("git_path/dcc_config.rb").and_return("before_each_bucket_group {}")
          @project.before_each_bucket_group_code.should be_nil
        end

        it "should return the configured code" do
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
                before_each_bucket_group {"do some thing"}
              |)
          @project.before_each_bucket_group_code.should be_a(Proc)
          @project.before_each_bucket_group_code.call.should == "do some thing"
        end
      end

      describe "when providing the before_each_bucket tasks for a bucket" do
        it "should return an empty array if no before_each_bucket tasks are configured" do
          File.stub(:read).with("git_path/dcc_config.rb").and_return("")
          @project.before_bucket_tasks("default:bucket").should == []
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
                buckets :default do
                  before_each_bucket.performs_rake_tasks
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end
              |)
          @project.before_bucket_tasks("default:bucket").should == []
        end

        it "should not return the configured tasks of another bunch of buckets" do
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
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
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
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
          File.stub(:read).with("git_path/dcc_config.rb").and_return("")
          @project.after_bucket_tasks("default:bucket").should == []
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
                buckets :default do
                  after_each_bucket.performs_rake_tasks
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end
              |)
          @project.after_bucket_tasks("default:bucket").should == []
        end

        it "should not return the configured tasks of another bunch of buckets" do
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
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
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
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
          @project.e_mail_receivers('default:one').should == ['to@me.de']
        end

        it "should return an empty array if no address were specified" do
          File.stub(:read).with("git_path/dcc_config.rb").and_return("")
          @project.e_mail_receivers('default:one').should == []
          File.stub(:read).with("git_path/dcc_config.rb").and_return("send_notifications_to")
          @project.e_mail_receivers('default:one').should == []
        end

        it "should return the specified addresses" do
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
                send_notifications_to "to@me.de", "to@me.too"
              |)
          @project.e_mail_receivers('default:one').should == ['to@me.de', 'to@me.too']
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
                send_notifications_to %w(to@me.de to@me.too)
              |)
          @project.e_mail_receivers('default:one').should == ['to@me.de', 'to@me.too']
        end

        it "should use global addresses for buckets if no buckets addresses are given" do
          @project.e_mail_receivers('default:one').should == ['to@me.de']
        end

        it "should use buckets addresses instead of global ones if given" do
          @project.e_mail_receivers('extra:three').should == ['to@you.com']
        end

        describe "for special github repos" do
          before do
            File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
              send_notifications_to(:toaster => %w(to@me.de to@me.too), :infopark => 'kra@pof.ni',
                  :default => 'de@fau.lt')
            |)
            Net::HTTP.stub(:new).and_return(
              double('http', :use_ssl= => nil, :get => double('response', :body => '{}'))
            )
          end

          it "should use the specified addresses if the repo matches #1" do
            @project.stub(:url).and_return "git@github.com:toaster/project.git"
            @project.e_mail_receivers('default:one').should == %w(to@me.de to@me.too)
          end

          it "should use the specified addresses if the repo matches #2" do
            @project.stub(:url).and_return "https://github.com/infopark/project.git"
            @project.e_mail_receivers('default:one').should == %w(kra@pof.ni)
          end

          it "should use the default addresses if the repo does not match #1" do
            @project.stub(:url).and_return "git@github.com:phorsuedzie/project.git"
            @project.e_mail_receivers('default:one').should == %w(de@fau.lt)
          end

          it "should use the default addresses if the repo does not match #2" do
            @project.stub(:url).and_return "https://infopark.com/toaster/project.git"
            @project.e_mail_receivers('default:one').should == %w(de@fau.lt)
          end

          describe "for special buckets" do
            before do
              File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
                send_notifications_to(:toaster => %w(to@me.de to@me.too), :infopark => 'kra@pof.ni',
                    :default => 'de@fau.lt')
                buckets "extra" do
                  send_notifications_to(:phorsuedzie => "to@you.com")
                  bucket(:three).performs_rake_tasks('3a', '3b')
                end
              |)
            end

            it "should provide github specific addresses too" do
              @project.stub(:url).and_return "git@github.com:phorsuedzie/project.git"
              @project.e_mail_receivers('extra:three').should == %w(to@you.com)
            end

            it "should fall back to global configuration when no specific configuration matched" do
              @project.stub(:url).and_return "git@github.com:toaster/project.git"
              @project.e_mail_receivers('extra:three').should == %w(to@me.de to@me.too)
            end
          end

          context "when github user has public available e-mail address an no address is given" do
            let(:github_email_address) { "me@github.com" }

            before do
              http = double('http')
              http.should_receive(:use_ssl=).with(true).ordered
              http.should_receive(:get).with('/users/phorsuedzie').ordered.and_return(
                double('response', :body => %|{"email": #{github_email_address.to_json}}|)
              )
              Net::HTTP.should_receive(:new).with('api.github.com', 443).and_return http

              @project.stub(:url).and_return "git@github.com:phorsuedzie/project.git"
            end

            it "should use the github e-mail address prior to the default address" do
              @project.e_mail_receivers('default:one').should == %w(me@github.com)
            end

            context "that is nil" do
              let(:github_email_address) { nil }

              it "should use the default address" do
                @project.e_mail_receivers('default:one').should == %w(de@fau.lt)
              end
            end

            context "that is empty" do
              let(:github_email_address) { "" }

              it "should use the default address" do
                @project.e_mail_receivers('default:one').should == %w(de@fau.lt)
              end
            end
          end
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
          File.stub(:read).with("git_path/dcc_config.rb").and_return("")
          @project.dependencies.should == []
          File.stub(:read).with("git_path/dcc_config.rb").and_return("depends_upon")
          @project.dependencies.should == []
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon do
                end
              |)
          @project.update_dependencies
          @project.dependencies.should == []
        end

        it "should set the configured dependencies" do
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1"
                depends_upon.project "url2"
                depends_upon do
                  project "url3"
                  project "url4"
                end
              |)
          @project.update_dependencies
          urls = @project.dependencies.map {|d| d.url}
          urls.size.should == 4
          urls.should be_include('url1')
          urls.should be_include('url2')
          urls.should be_include('url3')
          urls.should be_include('url4')
        end

        it "should set the branch into the dependencies if given" do
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1", :branch => "branch1"
                depends_upon do
                  project "url2", :branch => "branch2"
                end
              |)
          @project.update_dependencies
          branches = @project.dependencies.map {|d| d.branch}
          branches.size.should == 2
          branches.should be_include('branch1')
          branches.should be_include('branch2')
        end

        it "should use the projects branch as default of the dependencies' branch" do
          @project.stub(:branch).and_return "current"
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1"
                depends_upon do
                  project "url2"
                end
              |)
          @project.update_dependencies
          @project.dependencies.map {|d| d.branch}.should == %w(current current)
        end

        it "should set the fallback branch into the dependencies if given" do
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1", :fallback_branch => "branch1"
                depends_upon do
                  project "url2", :fallback_branch => "branch2"
                end
              |)
          @project.update_dependencies
          branches = @project.dependencies.map {|d| d.fallback_branch}
          branches.size.should == 2
          branches.should be_include('branch1')
          branches.should be_include('branch2')
        end

        it "should update changed dependencies" do
          @project.stub(:branch).and_return "current"
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1", :branch => "branch1"
                depends_upon.project "url2", :fallback_branch => "branch1"
              |)
          @project.update_dependencies
          @git.stub(:current_commit).and_return('new commit')
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1", :branch => "branch2"
                depends_upon.project "url2", :fallback_branch => "branch2"
              |)
          @project.update_dependencies
          branches = @project.dependencies.map {|d| d.branch}
          branches.size.should == 2
          branches.should be_include('branch2')
          branches.should be_include('current')
          branches = @project.dependencies.map {|d| d.fallback_branch}
          branches.size.should == 2
          branches.should be_include('branch2')
          branches.should be_include(nil)
        end

        it "should delete removed dependencies" do
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1", :branch => "branch1"
              |)
          @project.update_dependencies
          @git.stub(:current_commit).and_return('new commit')
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url2", :branch => "branch1"
              |)
          @project.update_dependencies
          @project.dependencies.map {|d| d.url}.should == %w(url2)
        end

        it "should keep untouched dependencies" do
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1", :branch => "branch1", :fallback_branch => "branch2"
              |)
          @project.update_dependencies
          @git.stub(:current_commit).and_return('new commit')
          File.stub(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1", :branch => "branch1", :fallback_branch => "branch2"
              |)
          @project.update_dependencies
          @project.dependencies.map {|d| d.branch}.should == %w(branch1)
          @project.dependencies.map {|d| d.fallback_branch}.should == %w(branch2)
          @project.dependencies.map {|d| d.url}.should == %w(url1)
        end
      end
    end

    it "should compute the next build number by adding one to the highest for the current commit" do
      @project.stub(:builds).and_return(builds = double('builds'))
      builds.stub(:find).with(:first, :conditions => "commit_hash = 'the current commit'",
          :order => "build_number DESC").and_return(double('build', :build_number => 5))
      builds.stub(:where).with(commit_hash: 'the current commit').and_return(double.tap do |result|
        result.stub(:order).with(:build_number).and_return ["foo", "bar", double(build_number: 5)]
      end)

      @project.next_build_number.should == 6
    end

    it "should compute the next build number with 1 for the first build of a commit" do
      @project.stub(:builds).and_return(builds = double('builds'))
      builds.stub(:where).with(commit_hash: 'the current commit').and_return double(order: [])

      @project.next_build_number.should == 1
    end
  end

  describe "when updating the state" do
    before do
      @project.stub(:current_commit).and_return("456")
      @project.stub(:dependencies).and_return []
      @project.stub(:last_commit=)
      @project.stub(:build_requested=)
      @project.stub(:save)
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
      @project.stub(:dependencies).and_return [dep1 = double(''), dep2 = double('')]
      dep1.should_receive(:update_state)
      dep2.should_receive(:update_state)
      @project.update_state
    end
  end
end
