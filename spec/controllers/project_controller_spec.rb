require File.dirname(__FILE__) + '/../spec_helper'

describe ProjectController, "when delivering index" do
  it "should fetch all projects and assign them for the view" do
    Project.should_receive(:find).with(:all).and_return "the projects"
    get 'index'
    assigns[:projects].should == "the projects"
  end

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

  it "should redirect to index" do
    Project.stub!(:destroy)
    post 'delete', :id => 666
    response.should redirect_to(:action => :index)
  end
end

describe ProjectController, "when showing a project" do
  before do
    Project.stub!(:find).and_return nil
  end

  it "should fetch the project and assign it for the view" do
    Project.should_receive(:find).with("666").and_return "the project"
    get 'show', :id => 666
    assigns[:project].should == "the project"
  end

  it "should render the project view" do
    get 'show', :id => 666
    response.should render_template('project/show')
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
  before do
    Project.stub!(:find).and_return mock('project', :build_requested= => nil, :save => nil)
  end

  it "should set the build flag and save the project" do
    Project.should_receive(:find).with("666").and_return(project = mock('project'))
    project.should_receive(:build_requested=).with(true).ordered
    project.should_receive(:save).ordered
    post 'build', :id => 666
  end

  it "should redirect to index" do
    post 'build', :id => 666
    response.should redirect_to(:action => :index)
  end
end
