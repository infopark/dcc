class CreateProjects < ActiveRecord::Migration
  def self.up
    create_table :projects do |t|
      t.column :name, :string, :null => false
      t.column :url, :string, :null => false
    end
    add_index :projects, :name, :unique => true
  end

  def self.down
    drop_table :projects
  end
end
