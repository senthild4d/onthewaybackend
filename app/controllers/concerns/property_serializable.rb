require 'uri'

module PropertySerializable
  extend ActiveSupport::Concern

  private

  def preload_favorite_property_ids!(properties)
    @favorite_property_ids =
      if current_user
        property_ids = Array(properties).map(&:id)
        current_user.favorites.where(property_id: property_ids).pluck(:property_id).to_set
      else
        Set.new
      end
  end

  def property_favorited?(property)
    return false unless current_user

    if @favorite_property_ids
      @favorite_property_ids.include?(property.id)
    else
      current_user.favorites.exists?(property_id: property.id)
    end
  end

  def normalize_features(features)
    Property.normalize_features_hash(features)
  end

  def property_images_response(property)
    property.images.attachments.map do |attachment|
      {
        id: attachment.id,
        url: attachment_url(attachment)
      }
    end
  end

  def immersive_property_video_view_url(property, video_url)
    return nil if video_url.blank?

    base = base_url_with_prefix.chomp('/')
    "#{base}/venue_360_viewer.html?url=#{URI.encode_www_form_component(video_url)}"
  end

  def property_view_360_response(property, video_url)
    viewer_url = immersive_property_video_view_url(property, video_url)

    {
      available: viewer_url.present? && property.video_projection_equirectangular?,
      projection: property.video_projection,
      video_url: video_url,
      viewer_url: viewer_url
    }
  end

  def property_response(property, detailed: false)
    video_url = attachment_url(property.video)
    view_360 = property_view_360_response(property, video_url)

    data = {
      id: property.id,
      title: property.title,
      description: property.description,
      property_type: property.property_type,
      purpose: property.purpose,
      bedrooms: property.bedrooms,
      bathrooms: property.bathrooms,
      area_sqft: property.area_sqft,
      area_sqm: property.area_sqm,
      year_built: property.year_built,
      floor: property.floor,
      total_floors: property.total_floors,
      furnished: property.furnished,
      parking_spaces: property.parking_spaces,
      price: property.price,
      currency: property.currency,
      approval_status: property.approval_status,
      listing_status: property.listing_status,
      sold_at: property.sold_at&.iso8601,
      archived_at: property.archived_at&.iso8601,
      features: property.normalized_features,
      is_favorited: property_favorited?(property),
      submitted_at: property.submitted_at&.iso8601,
      approved_at: property.approved_at&.iso8601,
      rejected_at: property.rejected_at&.iso8601,
      rejection_reason: property.rejection_reason,
      address: {
        address1: property.address1,
        address2: property.address2,
        city: property.city,
        region: property.region,
        postal_code: property.postal_code,
        country: property.country,
        full_address: property.full_address
      },
      coordinates: property.coordinates? ? { latitude: property.latitude.to_f, longitude: property.longitude.to_f } : nil,
      images: property_images_response(property),
      video: video_url,
      video_projection: property.video_projection,
      has_360_view: view_360[:available],
      view_360_url: view_360[:viewer_url],
      immersive_video_view_url: view_360[:viewer_url],
      view_360: view_360,
      created_at: property.created_at&.iso8601,
      updated_at: property.updated_at&.iso8601
    }

    if detailed
      data[:owner] = {
        id: property.owner_id,
        uniq_identifier: property.owner&.uniq_identifier,
        name: property.owner&.name,
        phone: property.owner&.phone,
        email: property.owner&.email
      }
    end

    data
  end
end
