require File.dirname(__FILE__) + '/../spec_helper'

describe OverviewController, "when delivering index" do
  before do
    get 'index'
  end

  it "should render overview" do
    response.should render_template('index')
  end
end
