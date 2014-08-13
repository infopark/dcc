class CreateClusterStates < ActiveRecord::Migration
  def self.up
    create_table :cluster_states do |t|
      t.integer :minion_count, null: false, default: 0
    end
  end

  def self.down
    drop_table :cluster_states
  end
end
