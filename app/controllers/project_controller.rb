# encoding: utf-8
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

  def show
    render :json => Project.find(params[:id])
  end

  def list
    render :json => {:projects => Project.all}
  end

  def log
    bucket = Bucket.find(params[:id])
    render :json => {
      :log => bucket.log,
      :logs => bucket.logs.map {|l| l.log}
    }
  end

  def old_build
    b = Build.find(params[:id])
    pb = b.project.last_build(:before_build => b)
    render :json => {
      :build => b,
      :previous_build_id => pb ? pb.id : nil
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
