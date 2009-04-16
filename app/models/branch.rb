class Branch < ActiveRecord::Base
  belongs_to :project
  validate :must_have_name

  def must_have_name
    raise "name must not be blank" if name.blank?
  end
end
