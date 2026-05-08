# frozen_string_literal: true

# Shared payload for listing active PR users tied to a venue so clients can open
# 1:1 chats via POST /api/v1/chats { "user_id": "..." } and chat messages APIs.
module PrChatUsersHelpers
  extend ActiveSupport::Concern

  private

  def pr_chat_users_payload_for_venue(venue)
    return { pr_users: [], venue_id: nil } unless venue

    partnerships = venue.venue_pr_partnerships
                        .active
                        .includes(:user)
                        .order(Arel.sql("CASE venue_pr_partnerships.role WHEN 'master_pr' THEN 0 ELSE 1 END"))
                        .order(:created_at)

    {
      venue_id: venue.id,
      pr_users: partnerships.filter_map do |p|
        u = p.user
        next unless u

        {
          user_id: u.id.to_s,
          name: u.name,
          username: u.username,
          role: p.role,
          partnership_id: p.id.to_s
        }
      end,
      how_to_start_chat: {
        step_1: 'POST /api/v1/chats with JSON body { "user_id": "<user_id from pr_users>", "booking_id": "<booking_id>" } (creates or returns existing 1:1 chat scoped to the booking).',
        step_2: 'POST /api/v1/chats/:chat_id/messages with { "message": { "content": "...", "message_type": "text" } }.',
        websocket: 'Subscribe to ActionCable ChatChannel with chat_id for real-time delivery (see docs/WEBSOCKET_USAGE.md).'
      }
    }
  end

  # Who may request PR contact list for an event (mirrors need for guest ↔ PR comms).
  # Does not depend on EventsController#can_manage_event? so BookingsController can use it too.
  def can_access_event_pr_chat_users?(event)
    return true if current_user.role_admin?
    return true if event.creator_id == current_user.id
    if event.venue
      return true if event.venue.owner_id == current_user.id
      return true if event.venue.venue_staff.exists?(user_id: current_user.id, role: 'manager')
      return true if event.venue.venue_pr_partnerships.active.exists?(user_id: current_user.id)
    end
    if event.collaborator_type == 'brand' && event.collaborator_id == current_user.id
      return true
    end

    return true if event.bookings.exists?(user_id: current_user.id)

    return false unless Event.visible_to_user(current_user).exists?(event.id)

    event.status_published?
  end
end
