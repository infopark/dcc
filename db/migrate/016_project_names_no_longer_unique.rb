class ProjectNamesNoLongerUnique < ActiveRecord::Migration
  def self.up
    remove_index :projects, :name
    add_index :projects, :name
    add_index :projects, [:name, :branch, :owner], unique: true
  end

  def self.down
    remove_index :projects, [:name, :branch, :owner]
    remove_index :projects, :name
    add_index :projects, :name, unique: true
  end
end

