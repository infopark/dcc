class NotFinishedYet < RuntimeError
end


class Bucket < ActiveRecord::Base
  has_many :logs, :dependent => :delete_all
  belongs_to :build
  attr_lazy :log

  def to_s
    "#<Bucket; ID: #{id}, Task: #{name}, Build: #{build.identifier}, Project: #{build.project.name}>"
  end

  def <=>(other)
    name <=> other.name if other.is_a? Bucket
  end

  def build_error_log
    raise NotFinishedYet unless finished_at
    return unless code = build.project.for_error_log(name)
    self.error_log = code.call(log)
    save
  end

  def to_json(*args)
    {
      :id => id,
      :name => name,
      :status => status,
      :started_at => started_at,
      :finished_at => finished_at
    }.to_json(*args)
  end
end
