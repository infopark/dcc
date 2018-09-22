# encoding: utf-8
require 'spec_helper'

describe ProjectController do

context "when delivering index" do
  it "should render overview" do
    get 'index'
    expect(response).to render_template('index')
  end
end

context "when creating a project" do
  it "should create a project with the given name, url and branch" do
    project = mock_model(Project, :id => 666)
    expect(Project).to receive(:new).with({"name" => "the name", "url" => "the url",
        "branch" => "the branch"}).and_return project
    expect(project).to receive(:save)

    post 'create',
        params: {:project => {:name => 'the name', :url => 'the url', :branch => 'the branch'}}
  end

  it "renders the created project as json" do
    post 'create',
        params: {:project => {:name => 'the name', :url => 'the url', :branch => 'the branch'}}

    expect(JSON.parse(response.body)).to include(
      "name" => "the name",
      "url" => "the url",
      "branch" => "the branch",
      "build_requested" => nil,
      "last_build" => nil,
      "last_system_error" => nil,
      "owner" => nil,
    )
    expect(JSON.parse(response.body)["id"]).to be
  end

  shared_examples_for "creating a personal project" do
    it "sets the owner to the currently logged in user" do
      expect(Project).to receive(:new).with(hash_including(owner: "max@muster.de")).
          and_return mock_model(Project, save: nil)
      post 'create',
          params: {project: {name: 'foo', url: 'bar', branch: 'master', personal: personal_value}}
    end
  end

  context "when “personal” is true" do
    let(:personal_value) { true }
    it_should_behave_like "creating a personal project"
  end

  context "when “personal” is “1”" do
    let(:personal_value) { "1" }
    it_should_behave_like "creating a personal project"
  end

  shared_examples_for "creating a non personal project" do
    it "does not set the owner" do
      expect(Project).to receive(:new).with(hash_excluding(:owner)).
          and_return mock_model(Project, save: nil)
      post 'create',
          params: {project: {name: 'foo', url: 'bar', branch: 'master', personal: personal_value}}
    end
  end

  context "when “personal” is false" do
    let(:personal_value) { false }
    it_should_behave_like "creating a non personal project"
  end

  context "when “personal” is nil" do
    let(:personal_value) { nil }
    it_should_behave_like "creating a non personal project"
  end

  context "when “personal” is “0”" do
    let(:personal_value) { "0" }
    it_should_behave_like "creating a non personal project"
  end
end

context "when deleting a project" do
  it "should remove the specified project" do
    expect(Project).to receive(:destroy).with("666")
    post 'delete', params: {:id => 666}
  end

  it "should render an empty json response" do
    allow(Project).to receive(:destroy)
    post 'delete', params: {:id => 666}
    expect(response.body).to eq("{}")
  end
end

context "when showing a build" do
  before do
    allow(Build).to receive(:find).and_return nil
  end

  it "should fetch the build and assign it for the view" do
    expect(Build).to receive(:find).with("666").and_return "the build"
    get 'show_build', params: {:id => 666}
    expect(assigns[:build]).to eq("the build")
  end

  it "should render the build view" do
    get 'show_build', params: {:id => 666}
    expect(response).to render_template('project/show_build')
  end
end

context "when showing a bucket" do
  let(:log_scope) { Bucket.select([:log, :error_log]) }
  before do
    log_scope
    allow(Bucket).to receive(:select).and_return log_scope
    allow(log_scope).to receive(:find).and_return nil
  end

  it "should fetch the bucket and assign it for the view" do
    expect(log_scope).to receive(:find).with("666").and_return "the bucket"
    get 'show_bucket', params: {:id => 666}
    expect(assigns[:bucket]).to eq("the bucket")
  end

  it "should render the bucket view" do
    get 'show_bucket', params: {:id => 666}
    expect(response).to render_template('project/show_bucket')
  end
end

context "when requesting a project to build" do
  before do
    allow(Project).to receive(:find).with("666").and_return(@project = double('project',
      :as_json => {updated: "project"},
      :build_requested= => nil,
      :save => nil
    ))
  end

  it "should set the build flag and save the project" do
    expect(@project).to receive(:build_requested=).with(true).ordered
    expect(@project).to receive(:save).ordered
    post 'build', params: {:id => 666}
  end

  it "renders the updated project as json" do
    post 'build', params: {:id => 666}
    expect(response.body).to eq('{"updated":"project"}')
  end
end

context "when showing a project" do
  before do
    allow(Project).to receive(:find).with("666").and_return double('project', :as_json => {the: 'project'})
    get "show", params: {:id => 666}
  end

  it "renders the project as json" do
    expect(response.body).to eq('{"the":"project"}')
  end
end

context "when requesting all projects" do
  before do
    allow(Project).to receive(:all).and_return [1, 2, 3, 4].map {|p| double(as_json: {p: p}) }
    get "list"
  end

  it "renders the projects as json" do
    expect(response.body).to eq('{"projects":[{"p":1},{"p":2},{"p":3},{"p":4}],"cluster_state":{"id":1,"minion_count":0}}')
  end
end

context "when requesting a bucket log" do
  let(:log_scope) { Bucket.select(:log) }
  before do
    log_scope
    allow(Bucket).to receive(:select).and_return log_scope
    allow(log_scope).to receive(:find).and_return double(
      log: "the complete log",
      logs: %w(some log fragments).map {|l| double(log: l) }
    )
  end

  it "explicitly asks for the bucket log" do
    expect(Bucket).to receive(:select).with(:log).ordered.and_return log_scope
    expect(log_scope).to receive(:find).ordered
    get "log", params: {id: 666}
  end

  it "uses the requested bucket" do
    expect(log_scope).to receive(:find).with("666").and_return Bucket.new
    get "log", params: {id: 666}
  end

  it "renders the log data as json" do
    get "log", params: {id: 666}
    expect(response.body).to eq(
        '{"log":"the complete log","logs":"somelogfragments"}'
    )
  end
end

context "when using the API" do
  before do
    allow(Rails.application.config).to receive_messages need_authorization: true
    Rails.configuration.dcc_api_key = "GOOD_KEY"
    allow(Build).to receive :find
  end

  let(:show_build_response) { get "show_build", params: {id: 666} }

  context "w/o credentials" do
    subject { show_build_response }
    it { is_expected.to be_redirect }
  end

  context "with HTTP auth" do
    let(:credentials) { ActionController::HttpAuthentication::Basic.encode_credentials user, "x" }
    before { request.env["HTTP_AUTHORIZATION"] = credentials }

    context "using wrong credentials" do
      let(:user) { "BAD_KEY" }
      subject { show_build_response }
      it { is_expected.to be_redirect }
    end

    context "using good credentials" do
      let(:user) { "GOOD_KEY" }

      subject { show_build_response }
      it { is_expected.to be_ok }

      context "non-public action" do
        subject { get "show_bucket", params: {id: 666} }
        it { is_expected.to be_redirect }
      end

      describe "session" do
        before { get "show_build", params: {id: 666} }
        subject { session }
        its([:user]) { is_expected.to be_blank }
      end
    end
  end
end

end
