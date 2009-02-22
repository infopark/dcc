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

  def delete
    Project.destroy(params[:id])
    redirect_to :action => :index
  end

  def create_branch
    Branch.new(params[:branch]).save
    redirect_to :action => :index
  end

  def delete_branch
    branch = Branch.find(params[:id])
    raise "last branch cannot be deleted" if branch.project.branches.size == 1
    branch.destroy
    redirect_to :action => :index
  end
end
