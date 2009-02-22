require File.dirname(__FILE__) + '/../spec_helper'

describe Project do
  fixtures :projects, :branches

  before(:each) do
    @project = Project.find(1)
  end

  it "should have a name" do
    @project.name.should == "project name"
  end

  it "should have an url" do
    @project.url.should == "project url"
  end

  it "should have branches" do
    @project.branches.size.should > 0
    @project.branches.each {|b| b.class.should == Branch}
  end
end

describe Project, "when creating a new one" do
  before(:each) do
  end

  it "should raise an error when a project with the given name already exists" do
    Project.new(:name => 'name', :url => 'url').save
    lambda {Project.new(:name => 'name', :url => 'a url').save}.should\
        raise_error(ActiveRecord::StatementInvalid)
  end

  it "should raise an error when the name was missing" do
    lambda {Project.new(:url => 'url').save}.should raise_error(/blank/)
  end

  it "should raise an error when the name left empty" do
    lambda {Project.new(:name => '', :url => 'url').save}.should raise_error(/blank/)
  end
end
