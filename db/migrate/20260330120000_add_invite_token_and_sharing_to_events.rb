# frozen_string_literal: true

class AddInviteTokenAndSharingToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :invite_token, :string
    add_column :events, :invite_sharing, :string, null: false, default: 'creator_and_guests'

    add_index :events, :invite_token, unique: true, where: 'invite_token IS NOT NULL', name: 'index_events_on_invite_token'

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          ALTER TABLE events ADD CONSTRAINT check_event_invite_sharing
          CHECK (invite_sharing IN ('creator_only', 'creator_and_guests'))
        SQL
      end
      dir.down do
        execute 'ALTER TABLE events DROP CONSTRAINT IF EXISTS check_event_invite_sharing'
      end
    end
  end
end
