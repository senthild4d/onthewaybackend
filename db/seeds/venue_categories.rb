# Venue type categories (restaurant, pub, cinema, etc.)
# Run with: rails db:seed (or load from seeds.rb)
# Idempotent: safe to run multiple times.

puts "Seeding venue categories..."

group = CategoriesGroup.find_or_initialize_by(slug: CategoriesGroup::VENUE_CATEGORIES_SLUG)
group.assign_attributes(
  name: 'Venue type',
  description: 'Type of venue (e.g. restaurant, pub, cinema)',
  display_order: (CategoriesGroup.maximum(:display_order) || -1) + 1
)
group.save!

# Slug must be globally unique; use venue_ prefix to avoid clash with event categories
# icon_key: Font Awesome class name (e.g. fa-lightbulb-o) for client to render icon
venue_types = [
  { name: 'Restaurant', slug: 'venue_restaurant', icon_key: 'fa-cutlery', display_order: 0 },
  { name: 'Pub', slug: 'venue_pub', icon_key: 'fa-beer', display_order: 1 },
  { name: 'Cinema', slug: 'venue_cinema', icon_key: 'fa-film', display_order: 2 },
  { name: 'Club', slug: 'venue_club', icon_key: 'fa-music', display_order: 3 },
  { name: 'Bar', slug: 'venue_bar', icon_key: 'fa-glass', display_order: 4 },
  { name: 'Cafe', slug: 'venue_cafe', icon_key: 'fa-coffee', display_order: 5 },
  { name: 'Hotel', slug: 'venue_hotel', icon_key: 'fa-bed', display_order: 6 },
  { name: 'Theater', slug: 'venue_theater', icon_key: 'fa-group', display_order: 7 },
  { name: 'Concert hall', slug: 'venue_concert_hall', icon_key: 'fa-music', display_order: 8 },
  { name: 'Gallery', slug: 'venue_gallery', icon_key: 'fa-picture-o', display_order: 9 },
  { name: 'Sports venue', slug: 'venue_sports', icon_key: 'fa-futbol-o', display_order: 10 },
  { name: 'Other', slug: 'venue_other', icon_key: 'fa-lightbulb-o', display_order: 99 }
]

venue_types.each do |attrs|
  cat = Category.find_or_initialize_by(slug: attrs[:slug])
  cat.assign_attributes(
    categories_group_id: group.id,
    name: attrs[:name],
    display_order: attrs[:display_order],
    icon_key: attrs[:icon_key]
  )
  cat.save!
end

puts "✓ Venue categories group and #{venue_types.size} venue types created/updated"
