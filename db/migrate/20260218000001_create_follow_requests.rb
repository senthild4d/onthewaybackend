class CreateFollowRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :follow_requests, id: :uuid do |t|
      t.uuid :requester_id, null: false
      t.uuid :requested_id, null: false
      t.string :status, default: 'pending', null: false
      t.datetime :responded_at
      t.timestamps
    end

    add_index :follow_requests, :requester_id
    add_index :follow_requests, :requested_id
    add_index :follow_requests, [:requester_id, :requested_id], unique: true, where: "status = 'pending'", name: 'index_follow_requests_pending_unique'
    add_index :follow_requests, :status
    add_foreign_key :follow_requests, :users, column: :requester_id, on_delete: :cascade
    add_foreign_key :follow_requests, :users, column: :requested_id, on_delete: :cascade
  end
end
