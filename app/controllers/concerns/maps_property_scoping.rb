# frozen_string_literal: true

module MapsPropertyScoping
  extend ActiveSupport::Concern

  private

  def show_map_properties?
    return param_truthy?(params[:show_properties]) if params.key?(:show_properties)

    # Legacy Vibes query params (venues/events → properties on this app)
    if params.key?(:show_venues) || params.key?(:show_events)
      return param_truthy?(params[:show_venues]) || param_truthy?(params[:show_events])
    end

    true
  end

  def param_truthy?(value)
    %w[false 0 off no].exclude?(value.to_s.strip.downcase)
  end

  def map_properties_scope
    scope = Property.includes(images_attachments: :blob, video_attachment: :blob, owner: { profile_picture_attachment: :blob })
    scope = scope.where.not(latitude: nil, longitude: nil)

    if current_user&.admin?
      # all listings; optional filters below
    elsif current_user
      scope = scope.where(
        '(approval_status = ? AND listing_status = ?) OR owner_id = ?',
        'approved', 'active', current_user.id
      )
    else
      scope = scope.visible_to_public
    end

    apply_map_property_filters(scope)
  end

  def apply_map_property_filters(scope)
    approval = params[:approval_status].presence || params[:status].presence || legacy_event_status_to_approval
    if approval.present? && current_user&.admin?
      scope = scope.where(approval_status: Array(approval))
    end

    listing = params[:listing_status].presence
    if listing.present? && current_user&.admin?
      scope = scope.where(listing_status: Array(listing))
    end

    scope = scope.where(country: params[:country]) if params[:country].present?
    scope = scope.where(region: params[:region]) if params[:region].present?
    scope = scope.where(city: params[:city]) if params[:city].present?
    scope = scope.where(purpose: params[:purpose]) if params[:purpose].present?
    scope = scope.where(currency: params[:currency]) if params[:currency].present?

    property_types = params[:property_type].presence || params[:category].presence
    scope = scope.where(property_type: Array(property_types)) if property_types.present?

    scope = scope.where('price >= ?', params[:min_price].to_d) if params[:min_price].present?
    scope = scope.where('price <= ?', params[:max_price].to_d) if params[:max_price].present?
    scope = scope.where('bedrooms >= ?', params[:min_bedrooms].to_i) if params[:min_bedrooms].present?
    scope = scope.where('bedrooms <= ?', params[:max_bedrooms].to_i) if params[:max_bedrooms].present?
    scope = scope.where('bathrooms >= ?', params[:min_bathrooms].to_i) if params[:min_bathrooms].present?
    scope = scope.where('bathrooms <= ?', params[:max_bathrooms].to_i) if params[:max_bathrooms].present?
    scope = scope.where('area_sqm >= ?', params[:min_area_sqm].to_d) if params[:min_area_sqm].present?
    scope = scope.where('area_sqm <= ?', params[:max_area_sqm].to_d) if params[:max_area_sqm].present?

    if params.key?(:has_360_view) && param_truthy?(params[:has_360_view])
      scope = scope.where(video_projection: 'equirectangular')
                   .joins(
                     "INNER JOIN active_storage_attachments property_video_attachments " \
                     "ON property_video_attachments.record_type = 'Property' " \
                     'AND property_video_attachments.record_id = properties.id ' \
                     "AND property_video_attachments.name = 'video'"
                   )
    end

    if params[:features].present?
      Array(params[:features]).map(&:to_s).reject(&:blank?).each do |key|
        scope = scope.where("features ->> ? = 'true'", key)
      end
    end

    apply_map_search(scope)
  end

  def apply_map_search(scope)
    term = (params[:search].presence || params[:q].presence).to_s.strip
    return scope if term.blank?

    like = "%#{term}%"
    scope.where(
      'title ILIKE ? OR description ILIKE ? OR city ILIKE ? OR region ILIKE ? OR country ILIKE ? OR address1 ILIKE ? OR address2 ILIKE ? OR postal_code ILIKE ? OR property_type ILIKE ?',
      like, like, like, like, like, like, like, like, like
    )
  end

  def apply_map_geo_filters(scope)
    if map_bounding_box_provided?
      scope = scope.where(
        'latitude >= ? AND latitude <= ? AND longitude >= ? AND longitude <= ?',
        params[:south].to_f,
        params[:north].to_f,
        params[:west].to_f,
        params[:east].to_f
      )
    elsif map_radius_search_provided?
      center_lat = params[:center_latitude].to_f
      center_lng = params[:center_longitude].to_f
      radius_km = params[:radius_km].to_f
      radius_km = 10.0 if radius_km <= 0

      lat_range = radius_km / 111.0
      lng_range = radius_km / (111.0 * Math.cos(center_lat * Math::PI / 180.0).abs.clamp(0.01, 1.0))

      scope = scope.where(
        'latitude >= ? AND latitude <= ? AND longitude >= ? AND longitude <= ?',
        center_lat - lat_range,
        center_lat + lat_range,
        center_lng - lng_range,
        center_lng + lng_range
      )
    end

    scope
  end

  def apply_map_sort(scope)
    case params[:sort_by].to_s
    when 'price_asc'
      scope.order(Arel.sql('price ASC NULLS LAST'), created_at: :desc)
    when 'price_desc'
      scope.order(Arel.sql('price DESC NULLS LAST'), created_at: :desc)
    when 'oldest'
      scope.order(created_at: :asc)
    when 'distance'
      apply_distance_sort(scope)
    else
      scope.order(created_at: :desc)
    end
  end

  def apply_distance_sort(scope)
    return scope.order(created_at: :desc) unless map_radius_search_provided?

    lat = params[:center_latitude].to_f
    lng = params[:center_longitude].to_f
    distance_order = ActiveRecord::Base.sanitize_sql_array(
      [
        '((properties.latitude - ?) * (properties.latitude - ?) + (properties.longitude - ?) * (properties.longitude - ?)) ASC NULLS LAST',
        lat, lat, lng, lng
      ]
    )
    scope.order(Arel.sql(distance_order), created_at: :desc)
  end

  def map_bounding_box_provided?
    %i[north south east west].all? { |k| params[k].present? }
  end

  def map_radius_search_provided?
    params[:center_latitude].present? && params[:center_longitude].present?
  end

  def legacy_event_status_to_approval
    case params[:event_status].to_s
    when 'published', 'live' then 'approved'
    when 'draft' then 'draft'
    when 'completed' then nil
    else nil
    end
  end

  def fetch_map_properties
    scope = map_properties_scope
    scope = apply_map_geo_filters(scope)
    limit = if params[:limit].present?
              [[params[:limit].to_i, 1].max, 500].min
            else
              200
            end
    apply_map_sort(scope).limit(limit).to_a
  end
end
