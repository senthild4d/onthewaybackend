# frozen_string_literal: true

# Platform fee configuration
# User side = charged to customer (attendee)
# Business side = charged to venue/brand/artist

module PlatformFees
  # --- USER SIDE (charged to customer) ---

  # Stripe processing fee: passed through to user (e.g. 2.5% of base)
  # Example: 10€ RSVP → 10 * 2.5% = 0.25€
  STRIPE_PROCESSING_PERCENTAGE = (ENV['STRIPE_PROCESSING_PERCENTAGE'] || 2.5).to_f
  STRIPE_PROCESSING_FIXED_CENTS = (ENV['STRIPE_PROCESSING_FIXED_CENTS'] || 0).to_i

  # RSVP platform fee: 5% on user side (when booking/RSVP)
  # Example: 10€ RSVP → 10 * 5% = 0.50€
  RSVP_PLATFORM_FEE_PERCENTAGE = (ENV['RSVP_PLATFORM_FEE_PERCENTAGE'] || 5).to_f

  # --- BUSINESS SIDE (charged to venue/brand/artist) ---

  # Exclusive event: 2%
  BUSINESS_FEE_EXCLUSIVE_PERCENTAGE = 2.0

  # Non-exclusive event: 5%
  BUSINESS_FEE_NON_EXCLUSIVE_PERCENTAGE = 5.0

  class << self
    # User-side: Stripe processing fee (e.g. 2.5% of base)
    def stripe_processing_fee(amount)
      return 0.to_d if amount.to_d <= 0
      (amount.to_d * STRIPE_PROCESSING_PERCENTAGE / 100) + (STRIPE_PROCESSING_FIXED_CENTS / 100.0)
    end

    # User-side: RSVP platform fee (5% of base)
    def rsvp_platform_fee(amount)
      return 0.to_d if amount.to_d <= 0
      amount.to_d * RSVP_PLATFORM_FEE_PERCENTAGE / 100
    end

    # User-side: Total fees (Stripe + RSVP) - both calculated on base amount
    # Example: 10€ → stripe 0.25€ + platform 0.50€ = 0.75€ → total 10.75€
    def user_total_fees(amount)
      base = amount.to_d
      return 0.to_d if base <= 0
      stripe_processing_fee(base) + rsvp_platform_fee(base)
    end

    # User-side: Total amount user pays (base + all fees)
    def user_total_amount(amount)
      amount.to_d + user_total_fees(amount)
    end

    # Business-side: Platform fee percentage for event (2% exclusive, 5% non-exclusive)
    def business_fee_percentage(pr_commission_type)
      case pr_commission_type.to_s
      when 'exclusive' then BUSINESS_FEE_EXCLUSIVE_PERCENTAGE
      when 'non_exclusive' then BUSINESS_FEE_NON_EXCLUSIVE_PERCENTAGE
      else 0
      end
    end

    # Business-side: Platform fee amount deducted from payout
    def business_fee_amount(amount, pr_commission_type)
      return 0.to_d if amount.to_d <= 0
      pct = business_fee_percentage(pr_commission_type)
      amount.to_d * pct / 100
    end

    # Business-side: Net amount venue/brand/artist receives
    def business_net_amount(amount, pr_commission_type)
      amount.to_d - business_fee_amount(amount, pr_commission_type)
    end
  end
end
