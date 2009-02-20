class OverviewController < ApplicationController
  def index
    Project.find(:all)
  end
end
