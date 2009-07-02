class ProcessedTasksController < ApplicationController
  def index
    @buckets = Bucket.find_all_by_status(30)
  end

  def failed
    bucket = Bucket.find(params[:id])
# TODO Status 'manuell failed' (37?)
# TODO worker killen/restarten oder sonstwas
    bucket.status = 35
    bucket.save
    redirect_to :action => :index
  end
end
