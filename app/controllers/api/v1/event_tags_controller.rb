# frozen_string_literal: true

module Api
  module V1
    class EventTagsController < ApplicationController
      before_action :require_authentication!, except: [:index]

      # GET /api/v1/event_tags
      # Query params: country (optional), include_trending (optional, default true)
      # Returns: default tags (All, festival, party) + country-specific tags + trending tags
      def index
        country = params[:country].to_s.strip.presence
        include_trending = params[:include_trending].to_s != 'false'

        tags = []

        # 1. Default tags (All, festival, party)
        default_tags = EventTag.default.global.ordered
        tags += default_tags.map { |t| tag_response(t, 'default') }

        # 2. Country-specific tags
        if country.present?
          country_tags = EventTag.for_country(country).ordered
          tags += country_tags.map { |t| tag_response(t, 'country') }
        end

        # 3. Trending tags (computed from upcoming event counts)
        if include_trending
          trending = trending_tags(country)
          tags += trending.map { |t| tag_response(t, 'trending') }
        end

        api_success(
          data: { tags: tags },
          status: :ok
        )
      end

      private

      def tag_response(tag, source = nil)
        base = {
          id: tag.respond_to?(:id) ? tag.id : nil,
          slug: tag.slug,
          name: tag.name,
          category_slug: tag.respond_to?(:category_slug) ? tag.category_slug : nil,
          events_count: tag.respond_to?(:events_count) ? tag.events_count : nil
        }
        base[:source] = source if source
        base[:country] = tag.country if tag.respond_to?(:country) && tag.country.present?
        base
      end

      def trending_tags(country)
        # Top categories by upcoming event count (last 30 days window for events starting soon)
        now = Time.current
        window_end = 30.days.from_now

        events = Event.published
                      .where('starts_at >= ? AND starts_at <= ?', now, window_end)
                      .joins(:venue)

        events = events.where(venues: { country: country }) if country.present?

        # Count by legacy category first (events.category)
        if events.respond_to?(:group)
          by_legacy = events.where.not(category: [nil, ''])
                            .group(:category)
                            .count

          # Also count by event_categories -> category slug
          by_category = events.joins(event_categories: :category)
                             .group('categories.slug')
                             .count

          # Merge: legacy category names become slugs (downcase, slugify)
          merged = {}
          by_legacy.each do |cat_name, count|
            slug = cat_name.to_s.parameterize
            merged[slug] = (merged[slug] || 0) + count
          end
          by_category.each do |slug, count|
            merged[slug.to_s] = (merged[slug.to_s] || 0) + count
          end

          # Top 5 trending, convert to tag-like structs
          merged.sort_by { |_, c| -c }.first(5).map do |slug, count|
            OpenStruct.new(
              slug: slug,
              name: slug.titleize,
              category_slug: slug,
              events_count: count,
              country: country
            )
          end
        else
          []
        end
      end
    end
  end
end
