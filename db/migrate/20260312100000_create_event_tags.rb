# frozen_string_literal: true

class CreateEventTags < ActiveRecord::Migration[7.1]
  def change
    create_table :event_tags, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.string :slug, null: false
      t.string :name, null: false
      t.string :country
      t.boolean :is_default, default: false, null: false
      t.integer :display_order, default: 0, null: false
      t.string :category_slug

      t.timestamps
    end

    add_index :event_tags, :slug, unique: true, where: 'country IS NULL', name: 'index_event_tags_on_slug_when_global'
    add_index :event_tags, [:slug, :country], unique: true, where: 'country IS NOT NULL', name: 'index_event_tags_on_slug_and_country'
    add_index :event_tags, :country
    add_index :event_tags, :is_default
  end
end
