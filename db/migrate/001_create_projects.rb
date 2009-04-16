class CreateProjects < ActiveRecord::Migration
  def self.up
    create_table :projects do |t|
      t.string :name, :url, :branch, :null => false
      t.string :last_commit
      t.boolean :build_requested
    end
    add_index :projects, :name, :unique => true

    create_table :buckets do |t|
      t.string :name, :commit, :null => false
      t.integer :build_number, :status, :null => false
      t.text :log
      t.belongs_to :project
    end
    add_index :buckets, [:name, :project_id, :commit], :unique => true
    add_index :buckets, :build_number
    add_index :buckets, :project_id
  end

  def self.down
    drop_table :buckets
    drop_table :projects
  end
end
