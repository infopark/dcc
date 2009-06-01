class Bucket < ActiveRecord::Base
  has_many :logs, :dependent => :delete_all
  belongs_to :build

  def to_s
    "#<Bucket; Task: #{name}, Build: #{build.identifier}, Project: #{build.project.name}>"
  end
end
