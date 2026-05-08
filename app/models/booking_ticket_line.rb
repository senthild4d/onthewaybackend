# frozen_string_literal: true

class BookingTicketLine < ApplicationRecord
  belongs_to :booking
  belongs_to :event_ticket_type
end
