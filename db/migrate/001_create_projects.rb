class CreateProjects < ActiveRecord::Migration
  def self.up
    create_table :projects do |t|
      t.string :name, :url, :branch, :null => false
      t.string :last_commit
      t.boolean :build_requested
    end

    create_table :buckets do |t|
      t.string :name, :null => false
      t.integer :build_number, :status, :null => false
      t.text :log
      t.belongs_to :project
    end
  end

  def self.down
    drop_table :buckets
    drop_table :projects
  end
end
