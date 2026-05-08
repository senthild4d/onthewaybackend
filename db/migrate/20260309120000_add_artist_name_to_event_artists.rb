# frozen_string_literal: true

class AddArtistNameToEventArtists < ActiveRecord::Migration[8.0]
  def up
    add_column :event_artists, :artist_name, :string

    # Allow artist_id to be null when using free-form artist_name
    change_column_null :event_artists, :artist_id, true

    # Drop and recreate unique index: only enforce uniqueness when artist_id is present.
    # Multiple free-form artists (artist_id NULL) per event are allowed.
    remove_index :event_artists, name: 'index_event_artists_event_artist_unique'
    add_index :event_artists, [:event_id, :artist_id],
              unique: true,
              name: 'index_event_artists_event_artist_unique',
              where: 'artist_id IS NOT NULL'
  end

  def down
    remove_index :event_artists, name: 'index_event_artists_event_artist_unique'
    add_index :event_artists, [:event_id, :artist_id],
              unique: true,
              name: 'index_event_artists_event_artist_unique'

    remove_column :event_artists, :artist_name
    change_column_null :event_artists, :artist_id, false
  end
end
