class CreateBranches < ActiveRecord::Migration
  def self.up
    create_table :branches do |t|
      t.column :name, :string, :null => false
      t.column :project_id, :integer, :null => false
    end
    add_index :branches, [:name, :project_id], :unique => true
  end

  def self.down
    drop_table :branches
  end
end
