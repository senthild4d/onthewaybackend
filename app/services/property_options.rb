class PropertyOptions
  class << self
    def form_options
      current_year = Date.current.year

      {
        currencies: currencies,
        purposes: purposes,
        property_types: property_types,
        features: features,
        furnished_options: furnished_options,
        bedroom_options: bedroom_options,
        bathroom_options: bathroom_options,
        parking_options: parking_options,
        floor_options: floor_options,
        area_units: area_units,
        year_built_range: { min: 1900, max: current_year, default: current_year },
        price_ranges: price_ranges,
        listing_statuses: listing_statuses,
        approval_statuses: approval_statuses,
        sort_options: sort_options,
        countries: countries,
        limits: {
          max_images: 20,
          max_image_size_mb: 10,
          max_video_size_mb: 200,
          max_title_length: 255
        }
      }
    end

    def filter_options(admin: false)
      scope = Property.visible_to_public

      options = {
        purposes: purposes,
        property_types: property_types,
        features: features,
        currencies: currencies,
        bedroom_options: bedroom_options,
        bathroom_options: bathroom_options,
        furnished_options: furnished_options,
        parking_options: parking_options,
        price_ranges: price_ranges,
        area_sqm_ranges: area_sqm_ranges,
        sort_options: sort_options,
        countries: countries,
        locations: {
          cities: scope.where.not(city: [nil, '']).distinct.order(:city).limit(100).pluck(:city),
          regions: scope.where.not(region: [nil, '']).distinct.order(:region).limit(100).pluck(:region),
          countries: scope.where.not(country: [nil, '']).distinct.order(:country).limit(50).pluck(:country)
        },
        filters: filter_param_docs
      }

      if admin
        options[:approval_statuses] = approval_statuses
        options[:listing_statuses] = listing_statuses
      end

      options
    end

    private

    def filter_param_docs
      {
        purpose: 'purpose',
        property_type: 'property_type (array)',
        country: 'country',
        region: 'region',
        city: 'city',
        min_price: 'min_price',
        max_price: 'max_price',
        min_bedrooms: 'min_bedrooms',
        max_bedrooms: 'max_bedrooms',
        min_bathrooms: 'min_bathrooms',
        max_bathrooms: 'max_bathrooms',
        min_area_sqm: 'min_area_sqm',
        max_area_sqm: 'max_area_sqm',
        features: 'features[]',
        search: 'search or q',
        sort_by: 'sort_by (newest, oldest, price_asc, price_desc)',
        page: 'page',
        per_page: 'per_page'
      }
    end

    def currencies
      [
        { value: 'USD', label: 'US Dollar', symbol: '$' },
        { value: 'EUR', label: 'Euro', symbol: '€' },
        { value: 'GBP', label: 'British Pound', symbol: '£' },
        { value: 'AED', label: 'UAE Dirham', symbol: 'د.إ' },
        { value: 'SAR', label: 'Saudi Riyal', symbol: '﷼' },
        { value: 'INR', label: 'Indian Rupee', symbol: '₹' },
        { value: 'PKR', label: 'Pakistani Rupee', symbol: '₨' },
        { value: 'CAD', label: 'Canadian Dollar', symbol: 'C$' },
        { value: 'AUD', label: 'Australian Dollar', symbol: 'A$' },
        { value: 'SGD', label: 'Singapore Dollar', symbol: 'S$' },
        { value: 'QAR', label: 'Qatari Riyal', symbol: 'ر.ق' },
        { value: 'KWD', label: 'Kuwaiti Dinar', symbol: 'د.ك' },
        { value: 'BHD', label: 'Bahraini Dinar', symbol: '.د.ب' },
        { value: 'OMR', label: 'Omani Rial', symbol: 'ر.ع.' },
        { value: 'EGP', label: 'Egyptian Pound', symbol: 'E£' },
        { value: 'TRY', label: 'Turkish Lira', symbol: '₺' }
      ]
    end

    def purposes
      [
        { value: 'sale', label: 'Sale' },
        { value: 'rent', label: 'Rent' }
      ]
    end

    def property_types
      [
        { value: 'apartment', label: 'Apartment' },
        { value: 'villa', label: 'Villa' },
        { value: 'townhouse', label: 'Townhouse' },
        { value: 'penthouse', label: 'Penthouse' },
        { value: 'studio', label: 'Studio' },
        { value: 'duplex', label: 'Duplex' },
        { value: 'land', label: 'Land' },
        { value: 'office', label: 'Office' },
        { value: 'shop', label: 'Shop' },
        { value: 'warehouse', label: 'Warehouse' },
        { value: 'building', label: 'Building' },
        { value: 'farm', label: 'Farm' },
        { value: 'other', label: 'Other' }
      ]
    end

    def features
      [
        { value: 'balcony', label: 'Balcony' },
        { value: 'garden', label: 'Garden' },
        { value: 'pool', label: 'Swimming Pool' },
        { value: 'gym', label: 'Gym' },
        { value: 'elevator', label: 'Elevator' },
        { value: 'security', label: '24/7 Security' },
        { value: 'parking', label: 'Parking' },
        { value: 'central_ac', label: 'Central A/C' },
        { value: 'maid_room', label: "Maid's Room" },
        { value: 'storage', label: 'Storage Room' },
        { value: 'pets_allowed', label: 'Pets Allowed' },
        { value: 'furnished', label: 'Furnished' },
        { value: 'sea_view', label: 'Sea View' },
        { value: 'city_view', label: 'City View' }
      ]
    end

    def furnished_options
      [
        { value: 'furnished', label: 'Furnished' },
        { value: 'unfurnished', label: 'Unfurnished' },
        { value: 'semi_furnished', label: 'Semi-Furnished' }
      ]
    end

    def bedroom_options
      [
        { value: '0', label: 'Studio' },
        { value: '1', label: '1 Bedroom' },
        { value: '2', label: '2 Bedrooms' },
        { value: '3', label: '3 Bedrooms' },
        { value: '4', label: '4 Bedrooms' },
        { value: '5', label: '5 Bedrooms' },
        { value: '6', label: '6 Bedrooms' },
        { value: '7', label: '7 Bedrooms' },
        { value: '8+', label: '8+ Bedrooms' }
      ]
    end

    def bathroom_options
      [
        { value: '1', label: '1 Bathroom' },
        { value: '2', label: '2 Bathrooms' },
        { value: '3', label: '3 Bathrooms' },
        { value: '4', label: '4 Bathrooms' },
        { value: '5', label: '5 Bathrooms' },
        { value: '6', label: '6 Bathrooms' },
        { value: '7+', label: '7+ Bathrooms' }
      ]
    end

    def parking_options
      [
        { value: '0', label: 'No Parking' },
        { value: '1', label: '1 Space' },
        { value: '2', label: '2 Spaces' },
        { value: '3', label: '3 Spaces' },
        { value: '4', label: '4 Spaces' },
        { value: '5+', label: '5+ Spaces' }
      ]
    end

    def floor_options
      [
        { value: '-2', label: 'Basement 2' },
        { value: '-1', label: 'Basement 1' },
        { value: '0', label: 'Ground Floor' },
        { value: '1', label: '1st Floor' },
        { value: '2', label: '2nd Floor' },
        { value: '3', label: '3rd Floor' },
        { value: '4', label: '4th Floor' },
        { value: '5', label: '5th Floor' },
        { value: '6', label: '6th Floor' },
        { value: '7', label: '7th Floor' },
        { value: '8', label: '8th Floor' },
        { value: '9', label: '9th Floor' },
        { value: '10', label: '10th Floor' },
        { value: 'penthouse', label: 'Penthouse' }
      ]
    end

    def area_units
      [
        { value: 'sqft', label: 'Square Feet (sq ft)' },
        { value: 'sqm', label: 'Square Meters (sq m)' }
      ]
    end

    def price_ranges
      {
        sale: [
          { min: 0, max: 100_000, label: 'Under 100K' },
          { min: 100_000, max: 250_000, label: '100K - 250K' },
          { min: 250_000, max: 500_000, label: '250K - 500K' },
          { min: 500_000, max: 1_000_000, label: '500K - 1M' },
          { min: 1_000_000, max: 2_500_000, label: '1M - 2.5M' },
          { min: 2_500_000, max: 5_000_000, label: '2.5M - 5M' },
          { min: 5_000_000, max: 10_000_000, label: '5M - 10M' },
          { min: 10_000_000, max: nil, label: 'Above 10M' }
        ],
        rent: [
          { min: 0, max: 500, label: 'Under 500' },
          { min: 500, max: 1_000, label: '500 - 1K' },
          { min: 1_000, max: 2_500, label: '1K - 2.5K' },
          { min: 2_500, max: 5_000, label: '2.5K - 5K' },
          { min: 5_000, max: 10_000, label: '5K - 10K' },
          { min: 10_000, max: 25_000, label: '10K - 25K' },
          { min: 25_000, max: nil, label: 'Above 25K' }
        ]
      }
    end

    def area_sqm_ranges
      [
        { min: 0, max: 50, label: 'Under 50 sqm' },
        { min: 50, max: 100, label: '50 - 100 sqm' },
        { min: 100, max: 200, label: '100 - 200 sqm' },
        { min: 200, max: 500, label: '200 - 500 sqm' },
        { min: 500, max: 1000, label: '500 - 1000 sqm' },
        { min: 1000, max: nil, label: 'Above 1000 sqm' }
      ]
    end

    def listing_statuses
      [
        { value: 'active', label: 'Active' },
        { value: 'sold', label: 'Sold' },
        { value: 'archived', label: 'Archived' }
      ]
    end

    def approval_statuses
      [
        { value: 'draft', label: 'Draft' },
        { value: 'pending_review', label: 'Pending Review' },
        { value: 'approved', label: 'Approved' },
        { value: 'rejected', label: 'Rejected' },
        { value: 'archived', label: 'Archived' }
      ]
    end

    def sort_options
      [
        { value: 'newest', label: 'Newest First' },
        { value: 'oldest', label: 'Oldest First' },
        { value: 'price_asc', label: 'Price: Low to High' },
        { value: 'price_desc', label: 'Price: High to Low' }
      ]
    end

    def countries
      [
        { value: 'AE', label: 'United Arab Emirates', flag: '🇦🇪' },
        { value: 'SA', label: 'Saudi Arabia', flag: '🇸🇦' },
        { value: 'IN', label: 'India', flag: '🇮🇳' },
        { value: 'PK', label: 'Pakistan', flag: '🇵🇰' },
        { value: 'US', label: 'United States', flag: '🇺🇸' },
        { value: 'GB', label: 'United Kingdom', flag: '🇬🇧' },
        { value: 'CA', label: 'Canada', flag: '🇨🇦' },
        { value: 'AU', label: 'Australia', flag: '🇦🇺' },
        { value: 'SG', label: 'Singapore', flag: '🇸🇬' },
        { value: 'QA', label: 'Qatar', flag: '🇶🇦' },
        { value: 'KW', label: 'Kuwait', flag: '🇰🇼' },
        { value: 'BH', label: 'Bahrain', flag: '🇧🇭' },
        { value: 'OM', label: 'Oman', flag: '🇴🇲' },
        { value: 'EG', label: 'Egypt', flag: '🇪🇬' },
        { value: 'TR', label: 'Turkey', flag: '🇹🇷' }
      ]
    end
  end
end
