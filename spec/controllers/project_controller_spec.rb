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

describe ProjectController, "when creating a branch" do
  it "should create a branch with the given name" do
    branch = mock_model(Branch)
    Branch.should_receive(:new).with({"name" => "the name", "project_id" => 666}).
        and_return branch
    branch.should_receive(:save)

    post 'create_branch', {:branch => {:name => 'the name', :project_id => 666}}
  end

  it "should redirect to index" do
    post 'create_branch', {:branch => {:name => 'the name', :project_id => 666}}
    response.should redirect_to(:action => :index)
  end
end

describe ProjectController, "when deleting a branch" do
  it "should remove the specified branch" do
    project = mock_model(Project, :branches => [1, 2])
    branch = mock_model(Branch, :project => project)
    Branch.should_receive(:find).with("666").and_return branch
    branch.should_receive(:destroy)
    post 'delete_branch', :id => 666
  end

  it "should raise an error if the branch is the last one of the project" do
    project = mock_model(Project, :branches => [1])
    branch = mock_model(Branch, :project => project)
    Branch.should_receive(:find).with("666").and_return branch
    branch.should_not_receive(:destroy)
    lambda {post 'delete_branch', :id => 666}.should raise_error(/last/)
  end

  it "should redirect to index" do
    Branch.stub!(:find).and_return mock_model(Branch,
          :project => mock_model(Project, :branches => [1, 2]), :destroy => true)
    post 'delete_branch', :id => 666
    response.should redirect_to(:action => :index)
  end
end
