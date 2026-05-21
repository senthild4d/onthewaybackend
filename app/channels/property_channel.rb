# frozen_string_literal: true

class PropertyChannel < ApplicationCable::Channel
  def subscribed
    @property = Property.find_by(id: params[:property_id])
    return reject unless @property
    return reject unless can_subscribe?(@property)

    stream_from PropertyRealtimeService.property_stream(@property)
  end

  def unsubscribed
    # no-op
  end

  private

  def can_subscribe?(property)
    return true if current_user.admin?
    return true if property.owner_id == current_user.id

    property.approval_status_approved? && property.listing_status_active?
  end
end
