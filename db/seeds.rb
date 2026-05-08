# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Load payment provider seeds
load Rails.root.join('db', 'seeds', 'payment_providers.rb') if File.exist?(Rails.root.join('db', 'seeds', 'payment_providers.rb'))

# Venue type categories (restaurant, pub, cinema, etc.)
load Rails.root.join('db', 'seeds', 'venue_categories.rb') if File.exist?(Rails.root.join('db', 'seeds', 'venue_categories.rb'))

# Event tags (default: All, festival, party; country-specific)
load Rails.root.join('db', 'seeds', 'event_tags.rb') if File.exist?(Rails.root.join('db', 'seeds', 'event_tags.rb'))
