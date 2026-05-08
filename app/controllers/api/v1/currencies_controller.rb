module Api
  module V1
    class CurrenciesController < ApplicationController
      # GET /api/v1/currencies
      def index
        currencies = base_currencies
        current_code = detect_current_currency_for(current_user)

        currencies = currencies.map do |currency|
          currency.merge(current: currency[:code] == current_code)
        end

        api_success(
          data: {
            currencies: currencies
          },
          status: :ok
        )
      end

      private

      def base_currencies
        [
          { code: 'USD', name: 'US Dollar', symbol: '$', icon: '🇺🇸' },
          { code: 'EUR', name: 'Euro', symbol: '€', icon: '🇪🇺' },
          { code: 'GBP', name: 'British Pound', symbol: '£', icon: '🇬🇧' },
          { code: 'CAD', name: 'Canadian Dollar', symbol: '$', icon: '🇨🇦' },
          { code: 'AUD', name: 'Australian Dollar', symbol: '$', icon: '🇦🇺' },
          { code: 'AED', name: 'UAE Dirham', symbol: 'د.إ', icon: '🇦🇪' },
          { code: 'SAR', name: 'Saudi Riyal', symbol: '﷼', icon: '🇸🇦' },
          { code: 'INR', name: 'Indian Rupee', symbol: '₹', icon: '🇮🇳' },
          { code: 'PKR', name: 'Pakistani Rupee', symbol: '₨', icon: '🇵🇰' },
          { code: 'BDT', name: 'Bangladeshi Taka', symbol: '৳', icon: '🇧🇩' }
        ]
      end

      # Try to infer the best currency for the current user
      # based on their stored location's formatted_address.
      def detect_current_currency_for(user)
        return nil unless user

        snapshot = user.current_location_snapshot
        country = extract_country_from_address(snapshot.formatted_address)
        return nil unless country

        country_key = country.downcase

        country_to_currency[country_key]
      rescue StandardError
        nil
      end

      def extract_country_from_address(formatted_address)
        return nil if formatted_address.blank?

        parts = formatted_address.split(',').map(&:strip)
        parts.last.presence
      end

      def country_to_currency
        @country_to_currency ||= begin
          mapping = {}

          # USD
          %w[united\ states usa us].each { |k| mapping[k] = 'USD' }

          # EUR (common EU countries – extend as needed)
          %w[germany france italy spain netherlands belgium portugal ireland finland austria].each do |k|
            mapping[k] = 'EUR'
          end
          mapping['european union'] = 'EUR'

          # GBP
          %w[united\ kingdom uk england scotland wales].each { |k| mapping[k] = 'GBP' }

          # CAD
          mapping['canada'] = 'CAD'

          # AUD
          mapping['australia'] = 'AUD'

          # AED
          mapping['united arab emirates'] = 'AED'
          mapping['uae'] = 'AED'
          mapping['dubai'] = 'AED'

          # SAR
          mapping['saudi arabia'] = 'SAR'

          # INR
          mapping['india'] = 'INR'

          # PKR
          mapping['pakistan'] = 'PKR'

          # BDT
          mapping['bangladesh'] = 'BDT'

          mapping
        end
      end
    end
  end
end
