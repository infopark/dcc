# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def build_display_value(build)
    "#{build.identifier} verwaltet von #{build.leader_uri}"
  end

  def bucket_display_value(bucket)
    "#{bucket.name}#{" auf #{bucket.worker_uri}" if bucket.worker_uri}"
  end

  def bucket_display_status(bucket)
    display_status(bucket.status)
  end

  def build_display_status(build)
    display_status(build_status(build))
  end

  def display_status(status)
    case status
    when 10
      'done'
    when 20
      'pending'
    when 30
      'in work'
    when 35
      'processing failed'
    when 40
      'failed'
    else
      "unknown status #{status}"
    end
  end

  def build_status(build)
    build.buckets.map {|b| b.status}.sort.last
  end

  def status_css_class(status)
    case status
    when 10
      'success'
    when 20
      'pending'
    when 30
      'processing'
    when 35
      'failure'
    when 40
      'failure'
    end
  end
end
