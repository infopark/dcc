class Build < ActiveRecord::Base
  has_many :buckets, :dependent => :delete_all
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
end
