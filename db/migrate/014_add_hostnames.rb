class AddHostnames < ActiveRecord::Migration
  def self.up
    add_column :buckets, :worker_hostname, :string
    add_column :builds, :leader_hostname, :string
  end

  def self.down
    remove_column :builds, :leader_hostname
    remove_column :buckets, :worker_hostname
  end
end
