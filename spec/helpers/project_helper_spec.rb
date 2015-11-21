# encoding: utf-8
require File.dirname(__FILE__) + '/../spec_helper'

describe ProjectHelper do
  describe "last_build" do
    before do
      @project = Project.new
      @project.last_commit = 'der commit'
      @project.id = 666
    end

    it "should return the last build" do
      allow(Build).to receive(:find_last_by_project_id_and_commit_hash).with(666, 'der commit',
          :order => 'build_number').and_return('last build')
      expect(helper.last_build(@project)).to eq('last build')
    end
  end
end
