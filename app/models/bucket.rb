class Bucket < ActiveRecord::Base
  has_many :logs, :dependent => :delete_all
  belongs_to :project

  def commit
    read_attribute(:commit_hash)
  end

  def commit=(value)
    write_attribute(:commit_hash, value)
  end
end
