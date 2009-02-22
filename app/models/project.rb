class Project < ActiveRecord::Base
  has_many :branches
  validate :must_have_name

  def must_have_name
    raise "name must not be blank" if name.blank?
  end
end
