# frozen_string_literal: true

class OwnerDashboardChannel < ApplicationCable::Channel
  def subscribed
    return reject unless current_user.admin? || current_user.role_owner? || current_user.owned_properties.exists?

    stream_from PropertyRealtimeService.owner_dashboard_stream(current_user)
  end

  def unsubscribed
    # no-op
  end
end
