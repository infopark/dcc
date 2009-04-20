class Bucket < ActiveRecord::Base
  has_many :logs, :dependent => :delete_all
  belongs_to :project
end
