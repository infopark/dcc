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
