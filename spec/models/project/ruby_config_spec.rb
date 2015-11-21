# encoding: utf-8
require 'spec_helper'

describe Project, "when providing ruby version" do
  let(:project) { provide_project }

  context "when not configured" do
    before do
      provide_bucket_group_config nil
    end

    it "has no ruby version for the bucket groups" do
      expect(project.ruby_version('default:one')).to be_nil
      expect(project.ruby_version('default:two')).to be_nil
      expect(project.ruby_version('extra:three')).to be_nil
    end
  end

  context "when configured globally" do
    before do
      provide_bucket_group_config "run_with_ruby_version '1.2.3-p4'"
    end

    it "returns the configured version for all buckets" do
      expect(project.ruby_version('default:one')).to eq('1.2.3-p4')
      expect(project.ruby_version('default:two')).to eq('1.2.3-p4')
      expect(project.ruby_version('extra:three')).to eq('1.2.3-p4')
    end
  end

  context "when configured locally" do
    before do
      provide_bucket_group_config nil, "run_with_ruby_version '1.2.3-p4'"
    end

    it "returns the configured version for the bucket group where it is configured" do
      expect(project.ruby_version('default:one')).to be_nil
      expect(project.ruby_version('default:two')).to be_nil
      expect(project.ruby_version('extra:three')).to eq('1.2.3-p4')
    end
  end

  context "when configured globally and locally" do
    before do
      provide_bucket_group_config "run_with_ruby_version '1.2.3-p4'", "run_with_ruby_version '5.6'"
    end

    it "returns the local version for the bucket group where it is configured" do
      expect(project.ruby_version('extra:three')).to eq('5.6')
    end

    it "returns the global version for bucket groups without locally configured version" do
      expect(project.ruby_version('default:one')).to eq('1.2.3-p4')
      expect(project.ruby_version('default:two')).to eq('1.2.3-p4')
    end
  end
end
