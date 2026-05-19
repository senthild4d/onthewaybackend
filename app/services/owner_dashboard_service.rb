# frozen_string_literal: true

class OwnerDashboardService
  PERIODS = %w[weekly monthly 6months 1year].freeze

  def initialize(user)
    @user = user
    @properties = Property.where(owner_id: user.id)
  end

  def summary
    viewings = viewings_scope
    favorites_count = favorites_scope.count

    {
      total_properties: @properties.count,
      active_listings: @properties.where(approval_status: 'approved', listing_status: 'active').count,
      pending_review: @properties.where(approval_status: 'pending_review').count,
      approval_status: {
        draft: @properties.where(approval_status: 'draft').count,
        pending_review: @properties.where(approval_status: 'pending_review').count,
        approved: @properties.where(approval_status: 'approved').count,
        rejected: @properties.where(approval_status: 'rejected').count,
        archived: @properties.where(approval_status: 'archived').count
      },
      listing_status: {
        active: @properties.where(listing_status: 'active').count,
        sold: @properties.where(listing_status: 'sold').count,
        archived: @properties.where(listing_status: 'archived').count
      },
      purposes: {
        sale: @properties.where(purpose: 'sale').count,
        rent: @properties.where(purpose: 'rent').count
      },
      viewings: {
        total: viewings.count,
        pending: viewings.where(status: 'requested').count,
        confirmed: viewings.where(status: 'confirmed').count,
        completed: viewings.where(status: 'completed').count,
        cancelled: viewings.where(status: 'cancelled').count
      },
      favorites_on_listings: favorites_count,
      properties: recent_properties_summary
    }
  end

  def metrics(period:)
    since = period_to_since(period)
    period_key = normalize_period(period)

    viewings = viewings_scope.where('property_viewings.created_at >= ?', since)
    favorites = favorites_scope.where('favorites.created_at >= ?', since)
    created_in_period = @properties.where('properties.created_at >= ?', since)
    approved_in_period = @properties.where('properties.approved_at >= ?', since)
    sold_in_period = @properties.where('properties.sold_at >= ?', since)
    sold_value = sold_in_period.sum(:price).to_f

    {
      period: period_key,
      period_start: since.iso8601,
      listings: {
        properties_created: created_in_period.count,
        properties_approved: approved_in_period.count,
        properties_sold: sold_in_period.count,
        total_sale_value: sold_value
      },
      viewings: {
        total_requests: viewings.count,
        requested: viewings.where(status: 'requested').count,
        confirmed: viewings.where(status: 'confirmed').count,
        completed: viewings.where(status: 'completed').count,
        cancelled: viewings.where(status: 'cancelled').count
      },
      engagement: {
        favorites_added: favorites.count
      },
      rsvp: {
        total_rsvp_bookings: viewings.count,
        total_earned: 0.0
      },
      tickets: {
        total_tickets_sold: sold_in_period.count,
        total_earned: sold_value,
        refunded: 0.0,
        net: sold_value
      }
    }
  end

  def self.normalize_period(period)
    key = period.to_s.presence || 'monthly'
    PERIODS.include?(key) ? key : 'monthly'
  end

  def self.period_to_since(period)
    case normalize_period(period)
    when 'weekly' then 1.week.ago
    when '6months' then 6.months.ago
    when '1year' then 1.year.ago
    else 1.month.ago
    end
  end

  private

  def normalize_period(period)
    self.class.normalize_period(period)
  end

  def period_to_since(period)
    self.class.period_to_since(period)
  end

  def viewings_scope
    PropertyViewing.joins(:property).where(properties: { owner_id: @user.id })
  end

  def favorites_scope
    Favorite.joins(:property).where(properties: { owner_id: @user.id })
  end

  def recent_properties_summary
    @properties.order(created_at: :desc).limit(5).map do |property|
      {
        id: property.id,
        title: property.title,
        approval_status: property.approval_status,
        listing_status: property.listing_status,
        purpose: property.purpose,
        price: property.price,
        currency: property.currency,
        city: property.city,
        created_at: property.created_at&.iso8601
      }
    end
  end
end
