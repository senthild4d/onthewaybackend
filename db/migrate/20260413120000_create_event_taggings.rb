class CreateEventTaggings < ActiveRecord::Migration[8.0]
  def change
    create_table :event_taggings, id: :uuid do |t|
      t.uuid :event_id, null: false
      t.uuid :event_tag_id, null: false

      t.timestamps
    end

    add_index :event_taggings, :event_id
    add_index :event_taggings, :event_tag_id
    add_index :event_taggings, [:event_id, :event_tag_id], unique: true, name: 'index_event_taggings_on_event_id_and_event_tag_id'

    add_foreign_key :event_taggings, :events, on_delete: :cascade
    add_foreign_key :event_taggings, :event_tags, on_delete: :cascade
  end
end

