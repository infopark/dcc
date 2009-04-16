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
