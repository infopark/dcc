class ProjectController < ApplicationController
  def index
    @projects = Project.find(:all)
  end

  def create
    p = Project.new(params[:project])
    p.save
    redirect_to :action => :index
  end

  def delete
    Project.destroy(params[:id])
    redirect_to :action => :index
  end
end
