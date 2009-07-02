class AddLeaderUriToBuilds < ActiveRecord::Migration
  def self.up
    add_column :builds, :leader_uri, :string, :null => false, :default => 'unknown'
  end

  def self.down
    remove_column :builds, :leader_uri
  end
end

