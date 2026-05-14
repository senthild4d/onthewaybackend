module PropertySerializable
  extend ActiveSupport::Concern

  private

  def property_response(property, detailed: false)
    images = property.images.map { |img| attachment_url(img) }
    video_url = attachment_url(property.video)

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
      features: property.features || {},
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
      images: images,
      video: video_url,
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
