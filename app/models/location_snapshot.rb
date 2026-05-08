class LocationSnapshot
  include ActiveModel::Model
  include ActiveModel::Attributes

  SOURCES = %w[device manual device_pending].freeze

  attribute :lat, :float
  attribute :lng, :float
  attribute :formatted_address, :string
  attribute :place_id, :string
  attribute :source, :string
  attribute :recorded_at, :datetime

  validates :source, presence: true
  validates :lat, :lng, :formatted_address, :recorded_at, presence: true, unless: :device_pending?
  validates :lat, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :lng, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true
  validates :formatted_address, length: { maximum: 255 }, allow_blank: false
  validates :place_id, length: { maximum: 255 }, allow_blank: true
  validates :source, inclusion: { in: SOURCES }, allow_nil: true

  def self.from_hash(data)
    return new unless data.present?

    new(
      lat: normalize_coordinate(data['lat'] || data[:lat]),
      lng: normalize_coordinate(data['lng'] || data[:lng]),
      formatted_address: (data['formatted_address'] || data[:formatted_address])&.to_s&.strip,
      place_id: (data['place_id'] || data[:place_id])&.to_s&.strip,
      source: data['source'] || data[:source],
      recorded_at: parse_time(data['recorded_at'] || data[:recorded_at])
    )
  end

  def self.build_from_params(params, source:)
    attrs = params.to_h.symbolize_keys.slice(:lat, :lng, :formatted_address, :place_id)
    attrs[:lat] = normalize_coordinate(attrs[:lat])
    attrs[:lng] = normalize_coordinate(attrs[:lng])
    attrs[:formatted_address] = attrs[:formatted_address]&.strip
    attrs[:place_id] = attrs[:place_id]&.strip

    attrs.merge!(
      source: source,
      recorded_at: Time.current
    )

    new(attrs)
  end

  def as_json(_opts = {})
    {
      lat: lat,
      lng: lng,
      formatted_address: formatted_address,
      place_id: place_id,
      source: source,
      recorded_at: recorded_at&.iso8601
    }.compact
  end

  def device_pending?
    source == 'device_pending'
  end

  private_class_method def self.parse_time(value)
    return Time.current if value.blank?
    return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

    if Time.zone
      Time.zone.parse(value.to_s)
    else
      Time.parse(value.to_s)
    end
  rescue ArgumentError
    Time.current
  end

  private_class_method def self.normalize_coordinate(value)
    return if value.blank?

    Float(value)
  rescue ArgumentError, TypeError
    nil
  end
end

