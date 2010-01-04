class Bucket < ActiveRecord::Base
  has_many :logs, :dependent => :delete_all
  belongs_to :build

  def to_s
    "#<Bucket; ID: #{id}, Task: #{name}, Build: #{build.identifier}, Project: #{build.project.name}>"
  end

  def <=>(other)
    name <=> other.name if other.is_a? Bucket
  end
end
