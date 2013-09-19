class Build < ActiveRecord::Base
  has_many :buckets, :dependent => :destroy
  belongs_to :project

  def commit
    read_attribute(:commit_hash)
  end

  def commit=(value)
    write_attribute(:commit_hash, value)
  end

  def identifier
    "#{commit}.#{build_number}"
  end

  def to_s
    "#<Build; ID: #{id}, Identifier: #{identifier}, Project: #{project.name}>"
  end

  def gitweb_url_map
    @@gitweb_url_map ||=
        begin
          YAML.load_file("#{RAILS_ROOT}/config/gitweb_url_map.yml")
        rescue Errno::ENOENT
          {}
        end
  end

  def gitweb_url
    dummy, url_code = gitweb_url_map.find {|pattern, code| project.url =~ Regexp.new(pattern)}
    href = if url_code
      eval %Q|"#{url_code}"|
    end
  end

# FIXME tests
  def status
    buckets.map {|b| b.status}.sort.last
  end

  def buckets_for_status(status)
    buckets.select {|b| b.status == status}
  end

  def bucket_count(status)
    buckets_for_status(status).size
  end

  def to_json(*args)
    {
      :id => id,
      :identifier => identifier,
      :status => status,
      :bucket_state_counts => {
        "10" => bucket_count(10),
        "20" => bucket_count(20),
        "30" => bucket_count(30),
        "35" => bucket_count(35),
        "40" => bucket_count(40)
      },
      :started_at => started_at,
      :finished_at => finished_at,
      :short_identifier => "#{commit[0..7]}.#{build_number}",
      :leader_uri => leader_uri,
      :commit => commit,
      :gitweb_url => gitweb_url,
      :failed_buckets => (buckets_for_status(40) + buckets_for_status(35)),
      :pending_buckets => buckets_for_status(20),
      :in_work_buckets => buckets_for_status(30),
      :done_buckets => buckets_for_status(10)
    }.to_json(*args)
  end
end
