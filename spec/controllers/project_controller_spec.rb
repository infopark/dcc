# encoding: utf-8
require File.dirname(__FILE__) + '/../spec_helper'

describe ProjectController, "when delivering index" do
  it "should render overview" do
    get 'index'
    response.should render_template('index')
  end
end

describe ProjectController, "when creating a project" do
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
end

describe ProjectController, "when deleting a project" do
  it "should remove the specified project" do
    Project.should_receive(:destroy).with("666")
    post 'delete', :id => 666
  end
end

describe ProjectController, "when showing a build" do
  before do
    Build.stub!(:find).and_return nil
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

describe ProjectController, "when showing a bucket" do
  before do
    Bucket.stub!(:find).and_return nil
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

describe ProjectController, "when requesting a project to build" do
  it "should set the build flag and save the project" do
    Project.should_receive(:find).with("666").and_return(project = mock('project', :to_json => nil))
    project.should_receive(:build_requested=).with(true).ordered
    project.should_receive(:save).ordered
    post 'build', :id => 666
  end
end
