class AddLastSystemErrorColumnToProjects < ActiveRecord::Migration
  def self.up
    add_column :projects, :last_system_error, :text, :null => true, :limit => 20.megabytes
  end

  def self.down
    remove_column :projects, :last_system_error
  end
end
