class MakeRsvpStatusOptionalInEventInterests < ActiveRecord::Migration[8.0]
  def up
    # Remove the NOT NULL constraint and default value
    change_column_null :event_interests, :rsvp_status, true
    change_column_default :event_interests, :rsvp_status, nil
    
    # Update check constraint to allow NULL
    remove_check_constraint :event_interests, name: "check_rsvp_status"
    add_check_constraint :event_interests, 
      "rsvp_status IS NULL OR rsvp_status::text = ANY (ARRAY['yes'::character varying::text, 'no'::character varying::text, 'maybe'::character varying::text])", 
      name: "check_rsvp_status"
  end

  def down
    # Restore NOT NULL constraint and default value
    # First, set all NULL values to 'yes'
    execute "UPDATE event_interests SET rsvp_status = 'yes' WHERE rsvp_status IS NULL"
    
    change_column_default :event_interests, :rsvp_status, 'yes'
    change_column_null :event_interests, :rsvp_status, false
    
    # Restore original check constraint
    remove_check_constraint :event_interests, name: "check_rsvp_status"
    add_check_constraint :event_interests, 
      "rsvp_status::text = ANY (ARRAY['yes'::character varying::text, 'no'::character varying::text, 'maybe'::character varying::text])", 
      name: "check_rsvp_status"
  end
end

