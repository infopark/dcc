require File.dirname(__FILE__) + '/../spec_helper'

describe Build do
  fixtures :projects, :dependencies

  before do
    @dependency = Dependency.find(1)
  end

  it "should have a project" do
    @dependency.project.should_not be_nil
  end

  it "should have an url" do
    @dependency.url.should == "url1"
  end

  it "should have a last_commit" do
    @dependency.last_commit.should == "old"
  end
end
