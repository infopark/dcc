# encoding: utf-8
require 'spec_helper'

describe ProjectController do

context "when delivering index" do
  it "should render overview" do
    get 'index'
    response.should render_template('index')
  end
end

context "when creating a project" do
  it "should create a project with the given name, url and branch" do
    project = mock_model(Project, :id => 666)
    Project.should_receive(:new).with({"name" => "the name", "url" => "the url",
        "branch" => "the branch"}).and_return project
    project.should_receive(:save)

    post 'create', {:project => {:name => 'the name', :url => 'the url', :branch => 'the branch'}}
  end

  it "should redirect to index" do
    post 'create', {:project => {:name => 'the name', :url => 'the url', :branch => 'the branch'}}
    response.should redirect_to(:action => :index)
  end

  shared_examples_for "creating a personal project" do
    it "sets the owner to the currently logged in user" do
      Project.should_receive(:new).with(hash_including(owner: "dummy")).
          and_return mock_model(Project, save: nil)
      post 'create', project: {name: 'foo', url: 'bar', branch: 'master', personal: personal_value}
    end
  end

  context "when “personal” is true" do
    let(:personal_value) { true }
    it_should_behave_like "creating a personal project"
  end

  context "when “personal” is “1”" do
    let(:personal_value) { "1" }
    it_should_behave_like "creating a personal project"
  end

  shared_examples_for "creating a non personal project" do
    it "does not set the owner" do
      Project.should_receive(:new).with(hash_excluding(:owner)).
          and_return mock_model(Project, save: nil)
      post 'create', project: {name: 'foo', url: 'bar', branch: 'master', personal: personal_value}
    end
  end

  context "when “personal” is false" do
    let(:personal_value) { false }
    it_should_behave_like "creating a non personal project"
  end

  context "when “personal” is nil" do
    let(:personal_value) { nil }
    it_should_behave_like "creating a non personal project"
  end

  context "when “personal” is “0”" do
    let(:personal_value) { "0" }
    it_should_behave_like "creating a non personal project"
  end
end

context "when deleting a project" do
  it "should remove the specified project" do
    Project.should_receive(:destroy).with("666")
    post 'delete', :id => 666
  end

  it "should render an empty json response" do
    Project.stub(:destroy)
    post 'delete', :id => 666
    response.body.should == "{}"
  end
end

context "when showing a build" do
  before do
    Build.stub(:find).and_return nil
  end

  it "should fetch the build and assign it for the view" do
    Build.should_receive(:find).with("666").and_return "the build"
    get 'show_build', :id => 666
    assigns[:build].should == "the build"
  end

  it "should render the build view" do
    get 'show_build', :id => 666
    response.should render_template('project/show_build')
  end
end

context "when showing a bucket" do
  before do
    Bucket.stub(:find).and_return nil
  end

  it "should fetch the bucket and assign it for the view" do
    Bucket.should_receive(:find).with("666").and_return "the bucket"
    get 'show_bucket', :id => 666
    assigns[:bucket].should == "the bucket"
  end

  it "should render the bucket view" do
    get 'show_bucket', :id => 666
    response.should render_template('project/show_bucket')
  end
end

context "when requesting a project to build" do
  before do
    Project.stub(:find).with("666").and_return(@project = double('project',
      :as_json => {updated: "project"},
      :build_requested= => nil,
      :save => nil
    ))
  end

  it "should set the build flag and save the project" do
    @project.should_receive(:build_requested=).with(true).ordered
    @project.should_receive(:save).ordered
    post 'build', :id => 666
  end

  it "renders the updated project as json" do
    post 'build', :id => 666
    response.body.should == '{"updated":"project"}'
  end
end

context "when showing a project" do
  before do
    Project.stub(:find).with("666").and_return double('project', :as_json => {the: 'project'})
    get "show", :id => 666
  end

  it "renders the project as json" do
    response.body.should == '{"the":"project"}'
  end
end

context "when requesting all projects" do
  before do
    Project.stub(:all).and_return [1, 2, 3, 4].map {|p| double(as_json: {p: p}) }
    get "list"
  end

  it "renders the projects as json" do
    response.body.should == '{"projects":[{"p":1},{"p":2},{"p":3},{"p":4}]}'
  end
end

context "when requesting a bucket log" do
  let(:log_scope) { Bucket.select(:log) }
  before do
    log_scope
    Bucket.stub(:select).and_return log_scope
    log_scope.stub(:find).and_return double(
      log: "the complete log",
      logs: %w(some log fragments).map {|l| double(log: l) }
    )
  end

  it "explicitly asks for the bucket log" do
    Bucket.should_receive(:select).with(:log).ordered.and_return log_scope
    log_scope.should_receive(:find).ordered
    get "log", id: 666
  end

  it "uses the requested bucket" do
    log_scope.should_receive(:find).with("666").and_return Bucket.new
    get "log", :id => 666
  end

  it "renders the log data as json" do
    get "log", :id => 666
    response.body.should ==
        '{"log":"the complete log","logs":["some","log","fragments"]}'
  end
end

end
