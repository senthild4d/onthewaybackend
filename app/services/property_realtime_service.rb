# frozen_string_literal: true

class PropertyRealtimeService
  class << self
    def property_stream(property)
      "property_#{property.id}"
    end

    def owner_dashboard_stream(user_or_id)
      user_id = user_or_id.respond_to?(:id) ? user_or_id.id : user_or_id
      "owner_dashboard_#{user_id}"
    end

    def user_stream(user_or_id)
      user_id = user_or_id.respond_to?(:id) ? user_or_id.id : user_or_id
      "user_#{user_id}"
    end

    def property_updated(property, action:, actor: nil)
      payload = {
        type: 'property',
        action: action.to_s,
        property: property_payload(property),
        actor_id: actor&.id,
        timestamp: Time.current.iso8601
      }

      ActionCable.server.broadcast(property_stream(property), payload)
      broadcast_owner_dashboard(property.owner_id, action: "property_#{action}", property: property)
      payload
    end

    def viewing_updated(viewing, action:, actor: nil)
      viewing = viewing.reload
      property = viewing.property
      payload = {
        type: 'property_viewing',
        action: action.to_s,
        viewing: viewing_payload(viewing),
        property: property_payload(property),
        actor_id: actor&.id,
        timestamp: Time.current.iso8601
      }

      ActionCable.server.broadcast(property_stream(property), payload) if property
      ActionCable.server.broadcast(user_stream(viewing.user_id), payload)
      broadcast_owner_dashboard(property.owner_id, action: "viewing_#{action}", property: property, viewing: viewing) if property
      payload
    end

    def broadcast_owner_dashboard(owner_id, action:, property: nil, viewing: nil)
      return if owner_id.blank?

      owner = User.find_by(id: owner_id)
      payload = {
        type: 'owner_dashboard',
        action: action.to_s,
        property: property ? property_payload(property) : nil,
        viewing: viewing ? viewing_payload(viewing) : nil,
        summary: owner ? OwnerDashboardService.new(owner).summary : nil,
        timestamp: Time.current.iso8601
      }

      ActionCable.server.broadcast(owner_dashboard_stream(owner_id), payload)
      payload
    end

    private

    def property_payload(property)
      return nil unless property

      {
        id: property.id,
        title: property.title,
        approval_status: property.approval_status,
        listing_status: property.listing_status,
        purpose: property.purpose,
        price: property.price,
        currency: property.currency,
        city: property.city,
        coordinates: property.coordinates? ? {
          latitude: property.latitude.to_f,
          longitude: property.longitude.to_f
        } : nil,
        has_video: property.video.attached?,
        video_projection: property.video_projection,
        has_360_view: property.video.attached? && property.video_projection_equirectangular?,
        updated_at: property.updated_at&.iso8601
      }
    end

    def viewing_payload(viewing)
      {
        id: viewing.id,
        property_id: viewing.property_id,
        user_id: viewing.user_id,
        status: viewing.status,
        requested_for: viewing.requested_for&.iso8601,
        message: viewing.message,
        contact_phone: viewing.contact_phone,
        contact_email: viewing.contact_email,
        handled_by_id: viewing.handled_by_id,
        handled_at: viewing.handled_at&.iso8601,
        admin_notes: viewing.admin_notes,
        created_at: viewing.created_at&.iso8601,
        updated_at: viewing.updated_at&.iso8601
      }
    end
  end
end
