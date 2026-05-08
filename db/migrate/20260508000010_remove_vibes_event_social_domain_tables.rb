class RemoveVibesEventSocialDomainTables < ActiveRecord::Migration[8.0]
  # This app was cloned from "vibes" (events + venues + social + payments).
  # Real-estate version keeps Users + Properties + Auth + Support tooling.
  #
  # This migration is DESTRUCTIVE: it drops legacy tables and data.
  def up
    # Drop the most dependent tables first; CASCADE ensures FKs don't block cleanup.
    drop_tables_cascade!(
      # Event domain
      %w[
        event_taggings
        event_tags
        event_ticket_types
        ticket_entitlements
        booking_ticket_lines
        event_custom_categories
        event_categories
        event_interests
        event_artists
        event_boosts
        event_menus
        menu_items
        menu_categories
        event_posts
        event_reports
        vibe_checks
        waiter_calls
        live_streams
        stream_views
        promo_codes
        food_bar_order_items
        bill_splits
        food_bar_orders
        bookings
        events
      ],
      # Venue domain
      %w[
        venue_menu_items
        venue_menu_categories
        venue_menus
        venue_categories
        venue_follows
        venue_interests
        venue_pr_partnerships
        venue_staff
        venue_blocklists
        seats
        tables
        floor_plan_elements
        floor_plan_zones
        floor_plans
        venues
      ],
      # Stories + social graph
      %w[
        moments
        follow_requests
        follows
        likes
        ratings
      ],
      # Chats (tightly coupled with social in vibes)
      %w[
        chat_messages
        chats
        group_chat_messages
        group_chat_memberships
        group_chats
      ]
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Legacy vibes tables were dropped'
  end

  private

  def drop_tables_cascade!(*groups)
    groups.flatten.each do |table|
      execute %(DROP TABLE IF EXISTS "#{table}" CASCADE)
    end
  end
end

