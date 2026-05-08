class EnhanceEventInterestsForRsvp < ActiveRecord::Migration[8.0]
  def change
    add_column :event_interests, :rsvp_status, :string, default: 'yes', null: false
    add_column :event_interests, :guest_count, :integer, default: 0, null: false
    add_column :event_interests, :notes, :text
    add_column :event_interests, :responded_at, :datetime
    add_index :event_interests, :rsvp_status
    add_check_constraint :event_interests, "rsvp_status::text = ANY (ARRAY['yes'::character varying, 'no'::character varying, 'maybe'::character varying]::text[])", name: "check_rsvp_status"
  end
end

