# encoding: utf-8
require 'spec_helper'

describe Project, "#bucket_group_environment" do
  before do
    provide_bucket_group_config nil, local_config
  end

  let(:local_config) { nil }
  let(:project) { provide_project }

  context "when no environment was configured" do
    it "returns an empty hash" do
      expect(project.bucket_group_environment("default:one")).to eq({})
    end
  end

  context "when an environment was configured" do
    let(:local_config) { 'environment FOO: "bar", BUS: "fahr"' }

    it "returns it" do
      expect(project.bucket_group_environment("extra:three")).to eq({FOO: "bar", BUS: "fahr"})
    end
  end

  context "when an environment was configured which is not a hash" do
    let(:local_config) { 'environment "I’m not a dentist"' }

    it "fails" do
      expect {
        project.bucket_group_environment("extra:three")
      }.to raise_error("invalid environment spec")
    end
  end
end
