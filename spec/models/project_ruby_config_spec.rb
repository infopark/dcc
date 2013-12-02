# encoding: utf-8
require 'spec_helper'

describe Project, "when providing ruby version" do
  let(:git) do
    double("git",
      :current_commit => "current commit",
      :path => 'git_path',
      :remote_changed? => false
    )
  end

  let(:project) do
    Project.new(:name => "name", :url => "url", :branch => "branch").tap do |p|
      p.stub(:git).and_return git
    end
  end

  context "when not configured" do
    before do
      provide_bucket_group_config nil
    end

    it "has no ruby version for the bucket groups" do
      project.ruby_version('default:one').should be_nil
      project.ruby_version('default:two').should be_nil
      project.ruby_version('extra:three').should be_nil
    end
  end

  context "when configured globally" do
    before do
      provide_bucket_group_config "run_with_ruby_version '1.2.3-p4'"
    end

    it "returns the configured version for all buckets" do
      project.ruby_version('default:one').should == '1.2.3-p4'
      project.ruby_version('default:two').should == '1.2.3-p4'
      project.ruby_version('extra:three').should == '1.2.3-p4'
    end
  end

  context "when configured locally" do
    before do
      provide_bucket_group_config nil, "run_with_ruby_version '1.2.3-p4'"
    end

    it "returns the configured version for the bucket group where it is configured" do
      project.ruby_version('default:one').should be_nil
      project.ruby_version('default:two').should be_nil
      project.ruby_version('extra:three').should == '1.2.3-p4'
    end
  end

  context "when configured globally and locally" do
    before do
      provide_bucket_group_config "run_with_ruby_version '1.2.3-p4'", "run_with_ruby_version '5.6'"
    end

    it "returns the local version for the bucket group where it is configured" do
      project.ruby_version('extra:three').should == '5.6'
    end

    it "returns the global version for bucket groups without locally configured version" do
      project.ruby_version('default:one').should == '1.2.3-p4'
      project.ruby_version('default:two').should == '1.2.3-p4'
    end
  end
end
