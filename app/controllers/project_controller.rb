# encoding: utf-8
class ProjectController < ApplicationController
  def create
    personal = ActiveRecord::ConnectionAdapters::Column.value_to_boolean(
        params[:project].delete :personal)
    params[:project][:owner] = @current_user.login if personal
    p = Project.new(params[:project])
    p.save
    render :json => p
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
    bucket = Bucket.select(:log).find(params[:id])
    render :json => {
      :log => bucket.log,
      :logs => bucket.logs.map {|l| l.log}
    }
  end

  # FIXME test
  def previous_builds
    b = Build.find(params[:id])
    previous_builds = b.project.builds_before b, 11
    render json: {
      previous_builds: previous_builds[0, 10],
      continuation_handle: previous_builds.size == 11 ? previous_builds[9].id : nil
    }
  end

  # FIXME test
  # FIXME delete
  def old_build
    b = Build.find(params[:id])
    pb = b.project.last_build(:before_build => b)
    render :json => {
      :build => b,
      :previous_build_id => pb ? pb.id : nil
    }
  end

  # altes GUI
  def index
    render :layout => 'classic'
  end

  # altes GUI für statische Links (z.B. für Pull-Requests)
  def show_build
    @build = Build.find(params[:id])
    render :layout => 'classic'
  end

  def show_bucket
    @bucket = Bucket.find(params[:id])
    render :layout => 'classic'
  end
end
