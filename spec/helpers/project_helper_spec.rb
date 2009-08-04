require File.dirname(__FILE__) + '/../spec_helper'

describe ProjectHelper do
  describe 'project_display_status' do
    before do
      @project = Project.new
    end

    it "should return the display value of the last build's status" do
      helper.stub!(:last_build).with(@project).and_return('last build')
      helper.stub!(:build_display_status).with('last build').and_return("last build's status")
      helper.project_display_status(@project).should == "last build's status"
    end
  end

  describe "last_build" do
    before do
      @project = Project.new
      @project.last_commit = 'der commit'
      @project.id = 666
    end

    it "should return the last build" do
      Build.stub!(:find_last_by_project_id_and_commit_hash).with(666, 'der commit',
          :order => 'build_number').and_return('last build')
      helper.last_build(@project).should == 'last build'
    end
  end

  describe "project_status" do
    before do
      @project = Project.new
    end

    it "should return the last build's status" do
      helper.stub!(:last_build).with(@project).and_return('last build')
      helper.stub!(:build_status).with('last build').and_return("last build's status")
      helper.project_status(@project).should == "last build's status"
    end
  end
end
