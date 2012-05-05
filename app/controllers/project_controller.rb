class ProjectController < ApplicationController
  def create
    p = Project.new(params[:project])
    p.save
    redirect_to :action => :index
  end

  def delete
    Project.destroy(params[:id])
    render :json => {}
  end

  def build
    p = Project.find(params[:id])
    p.build_requested = true
    p.save
    render :json => p
  end

  def list
    render :json => {:projects => Project.find(:all)}
  end

  def log
    bucket = Bucket.find(params[:id])
    render :json => {
      :log => bucket.log,
      :logs => bucket.logs.map {|l| l.log}
    }
  end

  # alt für statische Links (z.B. für Pull-Requests)
  def show_build
    @build = Build.find(params[:id])
  end

  def show_bucket
    @bucket = Bucket.find(params[:id])
  end
end
