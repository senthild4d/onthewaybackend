class MakeVenueOptionalOnEvents < ActiveRecord::Migration[7.1]
  def change
    change_column_null :events, :venue_id, true
  end
end

