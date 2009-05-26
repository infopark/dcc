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

  def show
    @project = Project.find(params[:id])
  end

  def show_build
    @build = Build.find(params[:id])
  end

  def show_bucket
    @bucket = Bucket.find(params[:id])
  end

  def build
    p = Project.find(params[:id])
    p.build_requested = true
    p.save
    redirect_to :action => :index
  end
end
