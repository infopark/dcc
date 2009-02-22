require File.dirname(__FILE__) + '/../spec_helper'

describe Branch do
  fixtures :projects, :branches

  before(:each) do
    @branch = Branch.find(11)
  end

  it "should have a name" do
    @branch.name.should == "master"
  end

  it "should have a project" do
    @branch.project.class.should == Project
  end
end

describe Branch, "when creating a new one" do
  it "should raise an error when a branch with the given name and project already exists" do
    Branch.new(:name => 'name', :project_id => 1).save
    lambda {Branch.new(:name => 'name', :project_id => 1).save}.should\
        raise_error(ActiveRecord::StatementInvalid)
  end

  it "should raise an error when the name was missing" do
    lambda {Branch.new(:project_id => 1).save}.should raise_error(/blank/)
  end

  it "should raise an error when the name left empty" do
    lambda {Branch.new(:name => '', :project_id => 1).save}.should raise_error(/blank/)
  end
end

