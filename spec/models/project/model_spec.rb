# encoding: utf-8
require 'spec_helper'

describe Project do
  fixtures :projects, :builds, :dependencies, :buckets, :logs

  before(:each) do
    @project = Project.find(1)
  end

  it "should have an id" do
    expect(@project.id).to eq(1)
  end

  it "should have a name" do
    expect(@project.name).to eq("project name")
  end

  it "should have an url" do
    expect(@project.url).to eq("project url")
  end

  it "should have a branch" do
    expect(@project.branch).to eq("project branch")
  end

  it "may have an owner" do
    expect(@project.owner).to be_nil
    expect(Project.find(2).owner).to eq("project owner")
  end

  it "may have a last_commit" do
    expect(@project.last_commit).to be_nil
    expect(Project.find(2).last_commit).to eq("project's last commit")
  end

  it "may have the build_requested flag set" do
    expect(@project.build_requested).to be_nil
    expect(Project.find(2).build_requested).to be_truthy
    expect(Project.find(3).build_requested).to be_falsey
  end

  it "may have builds" do
    expect(@project.builds).to be_empty
    expect(Project.find(3).builds).not_to be_empty
  end

  it "may have dependencies" do
    expect(@project.dependencies).to be_empty
    expect(Project.find(3).dependencies).not_to be_empty
  end

  it "may have a last_system_error" do
    expect(@project.last_system_error).to be_nil
    expect(Project.find(3).last_system_error).to eq("project's last system error")
  end

  context "when deleting" do
    it "deletes itself and all it's builds, buckets and logs" do
      Project.destroy(3)
      expect {
        Project.find(3)
      }.to raise_error ActiveRecord::RecordNotFound
      [1, 3].each do |id|
        expect {
          Build.find(id)
        }.to raise_error ActiveRecord::RecordNotFound
      end
      [1, 2].each do |id|
        expect {
          Bucket.find(id)
        }.to raise_error ActiveRecord::RecordNotFound
      end
      [1, 2].each do |id|
        expect {
          Log.find(id)
        }.to raise_error ActiveRecord::RecordNotFound
      end
    end

    it "does not delete builds, buckets or logs of other projects" do
      Project.destroy(1)
      expect {
        Project.find(1)
      }.to raise_error ActiveRecord::RecordNotFound
      [1, 3].each {|id| Build.find(id) }
      [1, 2].each {|id| Bucket.find(id) }
      [1, 2].each {|id| Log.find(id) }
    end
  end

  describe "#as_json" do
    it "returns the project as json serializable structure" do
      expect(@project.as_json.with_indifferent_access).to eq({
        name: "project name",
        id: 1,
        url: "project url",
        branch: "project branch",
        build_requested: nil,
        last_build: nil,
        previous_build_id: nil,
        last_system_error: nil,
        owner: nil,
      }.with_indifferent_access)
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
    expect {Project.new(name: 'name', url: 'a url', branch: 'branch', owner: 'owner').save}.to\
        raise_error(ActiveRecord::StatementInvalid)
  end

  it "should raise an error when the name was missing" do
    expect {Project.new(:url => 'url', :branch => 'branch').save}.to raise_error(/blank/)
  end

  it "should raise an error when the name left empty" do
    expect {Project.new(:name => '', :url => 'url', :branch => 'branch').save}.
        to raise_error(/blank/)
  end

  it "should raise an error when the url was missing" do
    expect {Project.new(:name => 'name', :branch => 'branch').save}.to raise_error(/blank/)
  end

  it "should raise an error when the url left empty" do
    expect {Project.new(:url => '', :name => 'name', :branch => 'branch').save}.
        to raise_error(/blank/)
  end

  it "should raise an error when the branch was missing" do
    expect {Project.new(:url => 'url', :name => 'name').save}.to raise_error(/blank/)
  end

  it "should raise an error when the branch left empty" do
    expect {Project.new(:branch => '', :url => 'url', :name => 'name').save}.
        to raise_error(/blank/)
  end
end

describe Project do
  before do
    @project = Project.new(:name => "name", :url => "url", :branch => "branch")
  end

  describe "when determining the last build" do
    before do
      allow(@project).to receive(:id).and_return 'p_id'
      allow(Build).to receive(:find_last_by_project_id)
    end

    it "should return nil if it has no builds" do
      expect(@project.last_build).to be_nil
    end

    it "should return the last build of the available builds" do
      allow(Build).to receive(:where).with("project_id = ?", 'p_id').
          and_return ['predator', 'terminator', 'last action hero']
      expect(@project.last_build).to eq('last action hero')
    end

    it "should be able to return the last build before a specified build" do
      allow(Build).to receive(:where).with("project_id = ? AND id < 12345", 'p_id').
          and_return ['first in a row', 'somewhere in the middle', 'last man standing']
      expect(@project.last_build(:before_build => double(:id => 12345))).to eq('last man standing')
    end
  end

  describe "when providing git" do
    before do
      allow(@project).to receive(:id).and_return 123
    end

    it "should create a new git using name, url and branch" do
      expect(DCC::Git).to receive(:new).with("name", 123, "url", "branch").and_return "the git"
      expect(@project.git).to eq("the git")
    end

    it "should reuse an already created git" do
      expect(DCC::Git).to receive(:new).once.and_return "the git"
      expect(@project.git).to eq("the git")
      expect(@project.git).to eq("the git")
      expect(@project.git).to eq("the git")
    end
  end

  describe "with git" do
    before do
      @git = double("git", :current_commit => "the current commit", :path => 'git_path',
          :remote_changed? => false)
      allow(@project).to receive(:git).and_return @git
    end

    describe "when providing current commit" do
      it "should get and return the current commit" do
        expect(@project.current_commit).to eq("the current commit")
      end
    end

    describe "when reading the config" do
      it "should read the config only once" do
        expect(File).to receive(:read).with("git_path/dcc_config.rb").once.and_return ""
        @project.send(:read_config)
        @project.send(:read_config)
      end

      it "should reread the config if git commit changed" do
        allow(@git).to receive(:current_commit).and_return('old one')
        expect(File).to receive(:read).with("git_path/dcc_config.rb").twice.and_return ""
        @project.send(:read_config)
        allow(@git).to receive(:current_commit).and_return('new one')
        @project.send(:read_config)
      end
    end

    describe "when being asked if wants_build?" do
      before do
        allow(@project).to receive(:build_requested?).and_return false
        allow(@project).to receive(:last_commit).and_return 'the current commit'
        allow(@project).to receive(:dependencies).and_return [
              @dep1 = double('', :has_changed? => false),
              @dep2 = double('', :has_changed? => false)
            ]
        allow(@project).to receive(:update_dependencies)
        allow(@git).to receive(:update)
        allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return "rebuild_if {false}"
      end

      it "should say 'true' if the current commit is not the same as remote" do
        allow(@git).to receive(:remote_changed?).and_return true
        allow(@project).to receive(:current_commit).and_return 'new'
        expect(@project.wants_build?).to be_truthy
      end

      it "should say 'true' if the 'build_requested' flag is set" do
        allow(@project).to receive(:build_requested?).and_return true
        expect(@project.wants_build?).to be_truthy
      end

      it "should say 'true' if a dependency has changed" do
        allow(@dep2).to receive(:has_changed?).and_return true
        expect(@project.wants_build?).to be_truthy
      end

      it "should say 'true' if the 'rebuild_if' block returns 'true'" do
        allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return "rebuild_if {true}"
        expect(@project.wants_build?).to be_truthy
      end

      it "should not crash if no 'rebuild_if' block was given" do
        allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return ""
        @project.wants_build?
      end

      it "should say 'false' else" do
        expect(@project.wants_build?).to be_falsey
      end

      it "should update the dependencies prior to getting them" do
        expect(@project).to receive(:update_dependencies).ordered
        expect(@project).to receive(:dependencies).ordered
        @project.wants_build?
      end

      it "should update the repository prior to getting the current commit" do
        allow(@git).to receive(:remote_changed?).and_return true
        expect(@git).to receive(:update).ordered
        expect(@git).to receive(:current_commit).ordered
        @project.wants_build?
      end
    end

    describe "when providing configured information" do
      before do
        allow(@git).to receive(:current_commit).and_return('current commit')
        allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
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
        expect(File).to receive(:read).with("git_path/dcc_config.rb").and_return("")
        @project.buckets_tasks
      end

      it "should provide the configured tasks" do
        expect(@project.buckets_tasks).to eq({
              "default:one" => ["1a", "1b", "1c"],
              "default:two" => ["2"],
              "extra:three" => ["3a", "3b"],
              "nix weita:four" => ["4"]
            })
      end

      it "should provide the configured tasks for a given bucket" do
        expect(@project.bucket_tasks('default:one')).to eq(["1a", "1b", "1c"])
        expect(@project.bucket_tasks('huh?')).to eq([])
      end

      it "should provide the bucket group for a given bucket" do
        expect(@project.bucket_group('default:one')).to eq('default')
        expect(@project.bucket_group('default:two')).to eq('default')
        expect(@project.bucket_group('extra:three')).to eq('extra')
        expect(@project.bucket_group('huh?')).to be_nil
      end

      describe "when providing the “for_error_log” code for a bucket" do
        it "should return nil when there is no “for_error_log” code" do
          expect(@project.for_error_log("default:one")).to be_nil
        end

        it "should return the “for_error_log” code of the bucket group for the bucket" do
          expect(@project.for_error_log("extra:three").call).to eq("extra's error log")
          expect(@project.for_error_log("nix weita:four").call).to eq("nix weita's error log")
        end
      end

      describe "when providing the before_all tasks" do
        it "should return an empty array if no before_all tasks are configured" do
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return("")
          expect(@project.before_all_tasks("default:bucket")).to eq([])
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(
              "before_all.performs_rake_tasks")
          expect(@project.before_all_tasks("default:bucket")).to eq([])
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                buckets :default do
                  before_all.performs_rake_tasks
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end
              |)
          expect(@project.before_all_tasks("default:bucket")).to eq([])
        end

        it "should return the configured tasks" do
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                before_all.performs_rake_tasks %w(task_one task_two)
                buckets :default do
                  before_all.performs_rake_tasks %w(task_three task_four)
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end
              |)
          expect(@project.before_all_tasks("default:bucket")).to eq(
              %w(task_one task_two task_three task_four)
          )
        end

        it "should not return the configured tasks of another bunch of buckets" do
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                buckets :default do
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end

                buckets :other do
                  before_all.performs_rake_tasks %w(task_one task_two)
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end
              |)
          expect(@project.before_all_tasks("default:bucket")).to eq([])
        end
      end

      describe "when providing the before_all_code" do
        it "should return the before_all_code" do
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                before_all do
                  "before_all_code"
                end
              |)
          expect(@project.before_all_code).to be_a(Proc)
          expect(@project.before_all_code.call).to eq("before_all_code")
        end

        it "should return the before_all_code even if before_all was accessed later on without code" do
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                before_all do
                  "before_all_code"
                end

                before_all.performs_rake_tasks("bla")
              |)
          expect(@project.before_all_code).to be_a(Proc)
          expect(@project.before_all_code.call).to eq("before_all_code")
        end

        it "should return nil if no before_all-block was given" do
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return("")
          expect(@project.before_all_code).to be_nil
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return("before_all {}")
          expect(@project.before_all_code).to be_nil
        end
      end

      describe "when providing the before_each_bucket_group code" do
        it "should return nil if no before_each_bucket_group code is configured" do
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return("")
          expect(@project.before_each_bucket_group_code).to be_nil
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return("before_each_bucket_group {}")
          expect(@project.before_each_bucket_group_code).to be_nil
        end

        it "should return the configured code" do
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                before_each_bucket_group {"do some thing"}
              |)
          expect(@project.before_each_bucket_group_code).to be_a(Proc)
          expect(@project.before_each_bucket_group_code.call).to eq("do some thing")
        end
      end

      describe "when providing the before_each_bucket tasks for a bucket" do
        it "should return an empty array if no before_each_bucket tasks are configured" do
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return("")
          expect(@project.before_bucket_tasks("default:bucket")).to eq([])
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                buckets :default do
                  before_each_bucket.performs_rake_tasks
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end
              |)
          expect(@project.before_bucket_tasks("default:bucket")).to eq([])
        end

        it "should not return the configured tasks of another bunch of buckets" do
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                buckets :default do
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end

                buckets :other do
                  before_each_bucket.performs_rake_tasks %w(task_one task_two)
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end
              |)
          expect(@project.before_bucket_tasks("default:bucket")).to eq([])
        end

        it "should return the configured tasks" do
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                buckets :default do
                  before_each_bucket.performs_rake_tasks %w(task_one task_two)
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end
              |)
          expect(@project.before_bucket_tasks("default:bucket")).to eq(%w(task_one task_two))
        end
      end

      describe "when providing the after_each_bucket tasks for a bucket" do
        it "should return an empty array if no after_each_bucket tasks are configured" do
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return("")
          expect(@project.after_bucket_tasks("default:bucket")).to eq([])
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                buckets :default do
                  after_each_bucket.performs_rake_tasks
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end
              |)
          expect(@project.after_bucket_tasks("default:bucket")).to eq([])
        end

        it "should not return the configured tasks of another bunch of buckets" do
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                buckets :default do
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end

                buckets :other do
                  after_each_bucket.performs_rake_tasks %w(task_one task_two)
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end
              |)
          expect(@project.after_bucket_tasks("default:bucket")).to eq([])
        end

        it "should return the configured tasks" do
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                buckets :default do
                  after_each_bucket.performs_rake_tasks %w(task_one task_two)
                  bucket(:bucket).performs_rake_tasks("rake_task")
                end
              |)
          expect(@project.after_bucket_tasks("default:bucket")).to eq(%w(task_one task_two))
        end
      end

      describe "when providing the E-Mail addresses" do
        it "should return a single address in an array" do
          expect(@project.e_mail_receivers('default:one')).to eq(['to@me.de'])
        end

        it "should return an empty array if no address were specified" do
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return("")
          expect(@project.e_mail_receivers('default:one')).to eq([])
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return("send_notifications_to")
          expect(@project.e_mail_receivers('default:one')).to eq([])
        end

        it "should return the specified addresses" do
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                send_notifications_to "to@me.de", "to@me.too"
              |)
          expect(@project.e_mail_receivers('default:one')).to eq(['to@me.de', 'to@me.too'])
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                send_notifications_to %w(to@me.de to@me.too)
              |)
          expect(@project.e_mail_receivers('default:one')).to eq(['to@me.de', 'to@me.too'])
        end

        it "should use global addresses for buckets if no buckets addresses are given" do
          expect(@project.e_mail_receivers('default:one')).to eq(['to@me.de'])
        end

        it "should use buckets addresses instead of global ones if given" do
          expect(@project.e_mail_receivers('extra:three')).to eq(['to@you.com'])
        end

        describe "for special github repos" do
          before do
            allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
              send_notifications_to(:toaster => %w(to@me.de to@me.too), :infopark => 'kra@pof.ni',
                  :default => 'de@fau.lt')
            |)
            allow(Net::HTTP).to receive(:new).and_return(
              double('http', :use_ssl= => nil, :get => double('response', :body => '{}'))
            )
          end

          it "should use the specified addresses if the repo matches #1" do
            allow(@project).to receive(:url).and_return "git@github.com:toaster/project.git"
            expect(@project.e_mail_receivers('default:one')).to eq(%w(to@me.de to@me.too))
          end

          it "should use the specified addresses if the repo matches #2" do
            allow(@project).to receive(:url).and_return "https://github.com/infopark/project.git"
            expect(@project.e_mail_receivers('default:one')).to eq(%w(kra@pof.ni))
          end

          it "should use the default addresses if the repo does not match #1" do
            allow(@project).to receive(:url).and_return "git@github.com:phorsuedzie/project.git"
            expect(@project.e_mail_receivers('default:one')).to eq(%w(de@fau.lt))
          end

          it "should use the default addresses if the repo does not match #2" do
            allow(@project).to receive(:url).and_return "https://infopark.com/toaster/project.git"
            expect(@project.e_mail_receivers('default:one')).to eq(%w(de@fau.lt))
          end

          describe "for special buckets" do
            before do
              allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                send_notifications_to(:toaster => %w(to@me.de to@me.too), :infopark => 'kra@pof.ni',
                    :default => 'de@fau.lt')
                buckets "extra" do
                  send_notifications_to(:phorsuedzie => "to@you.com")
                  bucket(:three).performs_rake_tasks('3a', '3b')
                end
              |)
            end

            it "should provide github specific addresses too" do
              allow(@project).to receive(:url).and_return "git@github.com:phorsuedzie/project.git"
              expect(@project.e_mail_receivers('extra:three')).to eq(%w(to@you.com))
            end

            it "should fall back to global configuration when no specific configuration matched" do
              allow(@project).to receive(:url).and_return "git@github.com:toaster/project.git"
              expect(@project.e_mail_receivers('extra:three')).to eq(%w(to@me.de to@me.too))
            end
          end

          context "when github user has public available e-mail address an no address is given" do
            let(:github_email_address) { "me@github.com" }

            before do
              http = double('http')
              expect(http).to receive(:use_ssl=).with(true).ordered
              expect(http).to receive(:get).with('/users/phorsuedzie').ordered.and_return(
                double('response', :body => %|{"email": #{github_email_address.to_json}}|)
              )
              expect(Net::HTTP).to receive(:new).with('api.github.com', 443).and_return http

              allow(@project).to receive(:url).and_return "git@github.com:phorsuedzie/project.git"
            end

            it "should use the github e-mail address prior to the default address" do
              expect(@project.e_mail_receivers('default:one')).to eq(%w(me@github.com))
            end

            context "that is nil" do
              let(:github_email_address) { nil }

              it "should use the default address" do
                expect(@project.e_mail_receivers('default:one')).to eq(%w(de@fau.lt))
              end
            end

            context "that is empty" do
              let(:github_email_address) { "" }

              it "should use the default address" do
                expect(@project.e_mail_receivers('default:one')).to eq(%w(de@fau.lt))
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
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return("")
          expect(@project.dependencies).to eq([])
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return("depends_upon")
          expect(@project.dependencies).to eq([])
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon do
                end
              |)
          @project.update_dependencies
          expect(@project.dependencies).to eq([])
        end

        it "should set the configured dependencies" do
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1"
                depends_upon.project "url2"
                depends_upon do
                  project "url3"
                  project "url4"
                end
              |)
          @project.update_dependencies
          urls = @project.dependencies.map {|d| d.url}
          expect(urls.size).to eq(4)
          expect(urls).to be_include('url1')
          expect(urls).to be_include('url2')
          expect(urls).to be_include('url3')
          expect(urls).to be_include('url4')
        end

        it "should set the branch into the dependencies if given" do
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1", :branch => "branch1"
                depends_upon do
                  project "url2", :branch => "branch2"
                end
              |)
          @project.update_dependencies
          branches = @project.dependencies.map {|d| d.branch}
          expect(branches.size).to eq(2)
          expect(branches).to be_include('branch1')
          expect(branches).to be_include('branch2')
        end

        it "should use the projects branch as default of the dependencies' branch" do
          allow(@project).to receive(:branch).and_return "current"
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1"
                depends_upon do
                  project "url2"
                end
              |)
          @project.update_dependencies
          expect(@project.dependencies.map {|d| d.branch}).to eq(%w(current current))
        end

        it "should set the fallback branch into the dependencies if given" do
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1", :fallback_branch => "branch1"
                depends_upon do
                  project "url2", :fallback_branch => "branch2"
                end
              |)
          @project.update_dependencies
          branches = @project.dependencies.map {|d| d.fallback_branch}
          expect(branches.size).to eq(2)
          expect(branches).to be_include('branch1')
          expect(branches).to be_include('branch2')
        end

        it "should update changed dependencies" do
          allow(@project).to receive(:branch).and_return "current"
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1", :branch => "branch1"
                depends_upon.project "url2", :fallback_branch => "branch1"
              |)
          @project.update_dependencies
          allow(@git).to receive(:current_commit).and_return('new commit')
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1", :branch => "branch2"
                depends_upon.project "url2", :fallback_branch => "branch2"
              |)
          @project.update_dependencies
          branches = @project.dependencies.map {|d| d.branch}
          expect(branches.size).to eq(2)
          expect(branches).to be_include('branch2')
          expect(branches).to be_include('current')
          branches = @project.dependencies.map {|d| d.fallback_branch}
          expect(branches.size).to eq(2)
          expect(branches).to be_include('branch2')
          expect(branches).to be_include(nil)
        end

        it "should delete removed dependencies" do
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1", :branch => "branch1"
              |)
          @project.update_dependencies
          allow(@git).to receive(:current_commit).and_return('new commit')
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url2", :branch => "branch1"
              |)
          @project.update_dependencies
          expect(@project.dependencies.map {|d| d.url}).to eq(%w(url2))
        end

        it "should keep untouched dependencies" do
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1", :branch => "branch1", :fallback_branch => "branch2"
              |)
          @project.update_dependencies
          allow(@git).to receive(:current_commit).and_return('new commit')
          allow(File).to receive(:read).with("git_path/dcc_config.rb").and_return(%Q|
                depends_upon.project "url1", :branch => "branch1", :fallback_branch => "branch2"
              |)
          @project.update_dependencies
          expect(@project.dependencies.map {|d| d.branch}).to eq(%w(branch1))
          expect(@project.dependencies.map {|d| d.fallback_branch}).to eq(%w(branch2))
          expect(@project.dependencies.map {|d| d.url}).to eq(%w(url1))
        end
      end
    end

    it "should compute the next build number by adding one to the highest for the current commit" do
      allow(@project).to receive(:builds).and_return(builds = double('builds'))
      allow(builds).to receive(:find).with(:first, :conditions => "commit_hash = 'the current commit'",
          :order => "build_number DESC").and_return(double('build', :build_number => 5))
      allow(builds).to receive(:where).with(commit_hash: 'the current commit').and_return(double.tap do |result|
        allow(result).to receive(:order).with(:build_number).and_return ["foo", "bar", double(build_number: 5)]
      end)

      expect(@project.next_build_number).to eq(6)
    end

    it "should compute the next build number with 1 for the first build of a commit" do
      allow(@project).to receive(:builds).and_return(builds = double('builds'))
      allow(builds).to receive(:where).with(commit_hash: 'the current commit').and_return double(order: [])

      expect(@project.next_build_number).to eq(1)
    end
  end

  describe "when updating the state" do
    before do
      allow(@project).to receive(:current_commit).and_return("456")
      allow(@project).to receive(:dependencies).and_return []
      allow(@project).to receive(:last_commit=)
      allow(@project).to receive(:build_requested=)
      allow(@project).to receive(:save)
    end

    it "should set the last commit to the current commit and save the project" do
      expect(@project).to receive(:last_commit=).with("456").ordered
      expect(@project).to receive(:save).ordered
      @project.update_state
    end

    it "should unset the build request flag and save the project" do
      expect(@project).to receive(:build_requested=).with(false).ordered
      expect(@project).to receive(:save).ordered
      @project.update_state
    end

    it "should update the last commit of all dependencies and save them" do
      allow(@project).to receive(:dependencies).and_return [dep1 = double(''), dep2 = double('')]
      expect(dep1).to receive(:update_state)
      expect(dep2).to receive(:update_state)
      @project.update_state
    end
  end
end
