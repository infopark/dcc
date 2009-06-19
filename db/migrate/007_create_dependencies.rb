class CreateDependencies < ActiveRecord::Migration
  def self.up
    create_table :dependencies do |t|
      t.string :url, :last_commit, :null => false
      t.belongs_to :project
    end
    add_index :dependencies, :url, :unique => true
  end

  def self.down
    drop_table :dependencies
  end
end
