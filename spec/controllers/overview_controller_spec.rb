require File.dirname(__FILE__) + '/../spec_helper'

describe OverviewController, "when delivering index" do
  before do
  end

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
