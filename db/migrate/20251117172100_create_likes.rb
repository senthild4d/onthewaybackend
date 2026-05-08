class CreateLikes < ActiveRecord::Migration[8.0]
  def change
    create_table :likes, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :likeable, null: false, polymorphic: true, type: :uuid
      
      t.timestamps
    end

    add_index :likes, [:user_id, :likeable_type, :likeable_id], unique: true, name: 'index_likes_user_likeable_unique'
    add_check_constraint :likes, "likeable_type IN ('Event', 'Venue')", name: 'check_likeable_type'
  end
end

