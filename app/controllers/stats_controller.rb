class StatsController < ApplicationController
  def show
    builds = Build.where(project_id: params[:id]).order_by(:started_at).to_a
    builds = builds.select { |build| build.finished_at.present? && build.status == Build::DONE }
    builds_by_commit = builds.group_by(&:commit).values
    rows_by_commit = builds_by_commit.map do |builds_for_commit|
      secs = builds_for_commit.map { |build| build.finished_at - build.started_at }
      date = builds_for_commit.last.started_at.to_s[5, 5]
      [date, (secs.max / 60).round, (secs.min / 60).round]
    end

    data = {
      :name => Project.find(params[:id]).name,
      :rows => rows_by_commit,
      :max => rows_by_commit.map(&:second).max.try(:ceil) || 1
    }
    render :json => data
  end
end
