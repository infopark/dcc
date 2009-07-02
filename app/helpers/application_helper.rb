# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def build_display_value(build)
    "#{build.identifier} verwaltet von #{build.leader_uri}"
  end

  def bucket_display_value(bucket)
    "#{bucket.name}#{" auf #{bucket.worker_uri}" if bucket.worker_uri}"
  end

  def bucket_status(bucket)
    display_status(bucket.status)
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
end
