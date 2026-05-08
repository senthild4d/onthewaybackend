class CreateRatings < ActiveRecord::Migration[8.0]
  def change
    create_table :ratings, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :rateable, null: false, polymorphic: true, type: :uuid
      t.integer :rating, null: false
      t.text :comment
      t.string :moderation_status, default: 'approved', null: false
      t.datetime :published_at
      
      t.timestamps
    end
    
    add_index :ratings, :moderation_status
    add_index :ratings, :published_at
    add_index :ratings, [:user_id, :rateable_type, :rateable_id], unique: true, name: 'index_ratings_user_rateable_unique'
    add_check_constraint :ratings, "rating >= 1 AND rating <= 5", name: 'check_rating_range'
    add_check_constraint :ratings, "moderation_status IN ('pending', 'approved', 'rejected')", name: 'check_rating_moderation_status'
  end
end

