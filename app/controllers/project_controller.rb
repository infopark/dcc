class ProjectController < ApplicationController
  def index
    @projects = Project.find(:all)
  end

  def create
    p = Project.new(params[:project])
    p.save
    Branch.new(:name => 'master', :project_id => p.id).save
    redirect_to :action => :index
  end
end
