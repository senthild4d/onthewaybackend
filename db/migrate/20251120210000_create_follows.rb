class CreateFollows < ActiveRecord::Migration[8.0]
  def change
    create_table :follows, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :follower_id, null: false
      t.uuid :following_id, null: false
      t.timestamps

      t.index [:follower_id, :following_id], unique: true, name: 'index_follows_follower_following_unique'
      t.index :follower_id
      t.index :following_id
    end

    add_foreign_key :follows, :users, column: :follower_id, on_delete: :cascade
    add_foreign_key :follows, :users, column: :following_id, on_delete: :cascade
  end
end

