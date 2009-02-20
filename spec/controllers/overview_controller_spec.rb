require File.dirname(__FILE__) + '/../spec_helper'

describe OverviewController, "when delivering index" do
  before do
  end

  it "should fetch all projects" do
    Project.should_receive(:find).with(:all).and_return []
    get 'index'
  end

  it "should render overview" do
    get 'index'
    response.should render_template('index')
  end
end
