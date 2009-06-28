class ReorganizeDependencies < ActiveRecord::Migration
  def self.up
    add_column :dependencies, :branch, :string, :null => false, :default => 'master'
    change_column :dependencies, :last_commit, :string, :null => true
    remove_index :dependencies, :url
    add_index :dependencies, [:url, :project_id], :unique => true
  end

  def self.down
    remove_column :dependencies, :branch
    change_column :dependencies, :last_commit, :string, :null => false
    remove_index :dependencies, [:url, :project_id]
    add_index :dependencies, :url, :unique => true
  end
end

