class CityGroupChatManager
  class LocationParseError < StandardError; end

  def initialize(user)
    @user = user
  end

  # Extract city and country from formatted_address
  # This is a simple parser - you may want to use a geocoding service for better accuracy
  def extract_city_from_location(location_data)
    return nil unless location_data.present?
    
    formatted_address = location_data['formatted_address'] || location_data[:formatted_address]
    return nil unless formatted_address.present?

    # Try to parse city from formatted address
    # Common formats: "City, State, Country" or "Street, City, Country"
    parts = formatted_address.split(',').map(&:strip)
    
    # For Puerto Rico (PR), handle special case
    if formatted_address.match?(/\bPR\b|\bPuerto Rico\b/i)
      country = 'Puerto Rico'
      # Try to find city name (usually second to last or third to last part)
      city = parts.find { |p| !p.match?(/\bPR\b|\bPuerto Rico\b|\d{5}/i) && p.length > 2 } || parts[-2]
      return { city: city, country: country } if city.present?
    end

    # General parsing: assume city is second-to-last or third-to-last part
    # and country is last part
    if parts.length >= 2
      country = parts.last
      city = parts.length >= 3 ? parts[-2] : parts[0]
      return { city: city, country: country }
    end

    nil
  rescue => e
    Rails.logger.error "Error parsing city from location: #{e.message}"
    nil
  end

  # Find or create city-based group chat
  def find_or_create_city_group_chat(city:, country:)
    return nil unless city.present? && country.present?

    # Normalize city and country names
    city_normalized = city.strip.titleize
    country_normalized = country.strip.titleize

    # Find existing city-based group chat
    group_chat = GroupChat.city_based.by_city(city_normalized, country_normalized).first

    if group_chat.nil?
      # Create new city-based group chat
      # Use system admin or first admin user as creator
      admin_user = User.role_admin.first || User.first
      return nil unless admin_user

      group_chat = GroupChat.create!(
        name: "#{city_normalized}, #{country_normalized}",
        description: "Local group chat for #{city_normalized}, #{country_normalized}",
        created_by: admin_user,
        city: city_normalized,
        country: country_normalized,
        is_city_based: true,
        status: 'active'
      )
    end

    group_chat
  end

  # Add user to city-based group chats based on their current location
  def add_user_to_city_groups
    location_data = user.current_location
    return unless location_data.present?

    city_info = extract_city_from_location(location_data)
    return unless city_info.present?

    group_chat = find_or_create_city_group_chat(
      city: city_info[:city],
      country: city_info[:country]
    )

    return unless group_chat

    # Add user to the group chat if not already a member
    unless group_chat.member?(user)
      group_chat.add_member(user, role: 'member')
    end

    # Also add user to groups for all venues in that city
    add_user_to_venue_city_groups(city_info[:city], city_info[:country])

    group_chat
  end

  # Add user to group chats for all venues in the city
  def add_user_to_venue_city_groups(city, country)
    venues = Venue.active.by_city(city).by_country(country)
    
    venues.each do |venue|
      # For each venue, find or create a city-based group chat
      # This ensures users in a city see all venue-based groups
      group_chat = find_or_create_city_group_chat(city: city, country: country)
      next unless group_chat

      unless group_chat.member?(user)
        group_chat.add_member(user, role: 'member')
      end
    end
  end

  private

  attr_reader :user
end

