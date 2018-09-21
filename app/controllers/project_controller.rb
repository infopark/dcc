# encoding: utf-8
class ProjectController < ApplicationController
  prepend_around_filter :with_api_user, only: :show_build, if: -> { session[:user].blank? }

  def create
    if ActiveRecord::Type::Boolean.new.type_cast_from_database(params[:project].delete(:personal))
      params[:project][:owner] = @current_user.login
    end

    project = Project.new(params.require(:project).permit(:name, :url, :branch, :owner))
    project.save
    render :json => project
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
    render json: {projects: Project.all, cluster_state: ClusterState.instance}
  end

  def log
    bucket = Bucket.select(:log).find(params[:id])
    render json: {
      log: process_log(bucket.log),
      logs: process_log(bucket.logs.map {|l| l.log}.join),
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
    pb = b.project.build_before(b)
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
    @bucket = Bucket.select([:log, :error_log]).find(params[:id])
    render :layout => 'classic'
  end

  private

  def with_api_user
    session[:user] = DummyUser.new.attributes if api_key_valid?
    yield
  ensure
    session[:user] = nil
  end

  def api_key_valid?
    authenticate_with_http_basic { |user| Rails.configuration.dcc_api_key == user }
  end

  def process_log(log)
    Terminal::Renderer.new(log).render
  end
end
