# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def gitweb_url_map
    @@gitweb_url_map ||=
        begin
          YAML.load_file("#{RAILS_ROOT}/config/gitweb_url_map.yml")
        rescue Errno::ENOENT
          {}
        end
  end

  def build_gitweb_url(build)
    dummy, url_code = gitweb_url_map.find {|pattern, code| build.project.url =~ Regexp.new(pattern)}
    href = if url_code
      commit = build.commit
      eval %Q|"#{url_code}"|
    end
  end

  def build_display_identifier(build)
    identifier, build_number = build.identifier.split('.')
    "#{identifier[0..7]}#{".#{build_number}" if build_number}"
  end

  def build_display_details(build)
    "#{build.identifier} verwaltet von #{build.leader_uri}"
  end

  def bucket_display_details(bucket)
    "auf #{bucket.worker_uri}" if bucket.worker_uri
  end

  def bucket_display_status(bucket)
    display_status(bucket.status)
  end

  def build_display_status(build)
    "#{display_status(build_status(build))} (#{
      detailed_build_status(build).select {|s, count| count > 0}.map do |status, count|
        "#{count} #{display_status(status)}"
      end.join ", "
    })"
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

  def detailed_build_status(build)
    result = {}
    build.buckets.each {|b| result[b.status] = (result[b.status] ||= 0) + 1}
    result
  end

  def status_css_class(status)
    case status
    when 10
      'success'
    when 20
      'in_progress'
    when 30
      'in_progress'
    when 35
      'failure'
    when 40
      'failure'
    end
  end
end
