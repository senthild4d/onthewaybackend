# frozen_string_literal: true

class AddRsvpEnabledToVenues < ActiveRecord::Migration[8.0]
  def change
    add_column :venues, :rsvp_enabled, :boolean, null: false, default: true
  end
end
