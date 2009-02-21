require File.dirname(__FILE__) + '/../spec_helper'

describe ProjectController, "when delivering index" do
  it "should fetch all projects" do
    Project.should_receive(:find).with(:all).and_return []
    get 'index'
  end

  it "should assign the fetched projects for the view" do
    Project.stub!(:find).and_return "the projects"
    get 'index'
    assigns[:projects].should == "the projects"
  end

  it "should render overview" do
    get 'index'
    response.should render_template('index')
  end
end

describe ProjectController, "when creating a project" do
  it "should create a project with the given name and url and a 'master' branch" do
    project = mock_model(Project, :id => 666)
    Project.should_receive(:new).with({"name" => "the name", "url" => "the url"}).and_return project
    project.should_receive(:save)

    branch = mock_model(Branch)
    Branch.should_receive(:new).with({:name => "master", :project_id => 666}).and_return branch
    branch.should_receive(:save)

    post 'create', {:project => {:name => 'the name', :url => 'the url'}}
  end

  it "should redirect to index" do
    post 'create', {:project => {:name => 'the name', :url => 'the url'}}
    response.should redirect_to(:action => :index)
  end
end
