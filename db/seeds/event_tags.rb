# frozen_string_literal: true

# Default event tags: All, festival, party
# Run: rails runner "load 'db/seeds/event_tags.rb'"
# Or add to db/seeds.rb: load Rails.root.join('db', 'seeds', 'event_tags.rb')

[
  { slug: 'all', name: 'All', is_default: true, display_order: 0, category_slug: nil },
  { slug: 'festival', name: 'Festival', is_default: true, display_order: 1, category_slug: 'festivals' },
  { slug: 'party', name: 'Party', is_default: true, display_order: 2, category_slug: 'party-events' }
].each do |attrs|
  t = EventTag.find_or_initialize_by(slug: attrs[:slug], country: nil)
  t.assign_attributes(name: attrs[:name], is_default: attrs[:is_default], display_order: attrs[:display_order], category_slug: attrs[:category_slug])
  t.save!
end

# Example country-specific tags (UK)
[
  { slug: 'pub-crawl', name: 'Pub Crawl', country: 'UK', display_order: 0, category_slug: nil },
  { slug: 'afternoon-tea', name: 'Afternoon Tea', country: 'UK', display_order: 1, category_slug: nil }
].each do |attrs|
  t = EventTag.find_or_initialize_by(slug: attrs[:slug], country: attrs[:country])
  t.assign_attributes(name: attrs[:name], is_default: false, display_order: attrs[:display_order], category_slug: attrs[:category_slug])
  t.save!
end
