class CreateFloorPlanTables < ActiveRecord::Migration[8.0]
  def change
    # Floor Plans table - stores the main floor plan for each venue
    create_table :floor_plans, id: :uuid do |t|
      t.uuid :venue_id, null: false
      t.string :name, null: false
      t.text :description
      t.string :venue_type, null: false # e.g., 'restaurant', 'pub', 'bar', 'casino', 'gaming', 'sports'
      
      # Canvas/design dimensions
      t.integer :width, null: false, default: 1000 # Canvas width in pixels
      t.integer :height, null: false, default: 1000 # Canvas height in pixels
      t.decimal :scale_factor, precision: 10, scale: 2, default: 1.0 # Real-world to canvas scale (e.g., 1px = 10cm)
      
      # Floor plan metadata
      t.jsonb :settings, default: {}, null: false # Additional settings like grid size, units, etc.
      t.text :thumbnail_url # Preview image of the floor plan
      
      # Status
      t.string :status, default: 'draft', null: false # draft, active, archived
      t.boolean :is_default, default: false, null: false # Is this the default/active floor plan
      
      t.timestamps
    end
    
    # Floor Plan Zones - different areas within a venue (e.g., dining area, bar area, outdoor, VIP)
    create_table :floor_plan_zones, id: :uuid do |t|
      t.uuid :floor_plan_id, null: false
      t.string :name, null: false # e.g., 'Main Dining', 'Bar Area', 'VIP Section', 'Outdoor Patio'
      t.string :zone_type, null: false # e.g., 'dining', 'bar', 'vip', 'outdoor', 'stage', 'dance_floor'
      
      # Zone visual properties (stored as JSON for flexibility with Fabric.js or Konva.js)
      t.jsonb :geometry, null: false # Polygon points, rectangle bounds, or circle radius
      t.string :color, default: '#cccccc' # Zone background color
      t.integer :display_order, default: 0, null: false
      
      # Zone properties
      t.integer :capacity # Max capacity for this zone
      t.boolean :is_bookable, default: true, null: false
      t.boolean :is_active, default: true, null: false
      t.decimal :min_spend, precision: 10, scale: 2 # Minimum spend for VIP zones
      
      t.timestamps
    end
    
    # Tables - individual tables/seating arrangements
    create_table :tables, id: :uuid do |t|
      t.uuid :floor_plan_zone_id, null: false
      t.string :table_number, null: false # e.g., 'T1', 'T2', 'A1', 'B5'
      t.string :table_name # Optional friendly name
      
      # Table type and shape
      t.string :table_type, null: false # e.g., 'standard', 'booth', 'bar_stool', 'highchair', 'vip'
      t.string :shape, null: false # e.g., 'rectangle', 'circle', 'square', 'custom'
      
      # Position and dimensions on canvas
      t.decimal :x_position, precision: 10, scale: 2, null: false # X coordinate on canvas
      t.decimal :y_position, precision: 10, scale: 2, null: false # Y coordinate on canvas
      t.decimal :width, precision: 10, scale: 2, null: false # Width of table
      t.decimal :height, precision: 10, scale: 2, null: false # Height of table
      t.decimal :rotation, precision: 10, scale: 2, default: 0.0 # Rotation in degrees
      
      # Table properties
      t.integer :min_capacity, default: 1, null: false
      t.integer :max_capacity, null: false
      t.boolean :is_accessible, default: false # Wheelchair accessible
      t.boolean :is_active, default: true, null: false
      t.boolean :is_bookable, default: true, null: false
      
      # Visual properties
      t.string :color
      t.jsonb :custom_properties, default: {} # For custom shapes or additional properties
      
      t.timestamps
    end
    
    # Seats - individual seats at each table
    create_table :seats, id: :uuid do |t|
      t.uuid :table_id, null: false
      t.integer :seat_number, null: false # Sequential number (1, 2, 3, etc.)
      
      # Position relative to table or absolute
      t.decimal :x_position, precision: 10, scale: 2, null: false
      t.decimal :y_position, precision: 10, scale: 2, null: false
      t.string :position_label # e.g., 'left', 'right', 'top', 'bottom', 'north', 'south'
      
      # Seat properties
      t.boolean :is_active, default: true, null: false
      t.boolean :is_accessible, default: false # Wheelchair accessible seat
      t.string :seat_type, default: 'standard' # standard, highchair, wheelchair, bar_stool
      
      t.timestamps
    end
    
    # Additional elements (walls, decor, fixtures, etc.) - optional for advanced floor plans
    create_table :floor_plan_elements, id: :uuid do |t|
      t.uuid :floor_plan_id, null: false
      t.string :element_type, null: false # e.g., 'wall', 'door', 'window', 'pillar', 'decor', 'bar', 'stage'
      t.string :name
      
      # Position and geometry
      t.jsonb :geometry, null: false # Points, paths, or shapes
      t.string :color
      t.decimal :rotation, precision: 10, scale: 2, default: 0.0
      t.integer :display_order, default: 0, null: false
      
      # Properties
      t.jsonb :properties, default: {} # Additional properties specific to element type
      t.boolean :is_visible, default: true, null: false
      
      t.timestamps
    end
    
    # Indexes
    add_index :floor_plans, :venue_id
    add_index :floor_plans, [:venue_id, :is_default]
    add_index :floor_plans, :status
    add_index :floor_plans, :venue_type
    
    add_index :floor_plan_zones, :floor_plan_id
    add_index :floor_plan_zones, :zone_type
    add_index :floor_plan_zones, [:floor_plan_id, :display_order]
    
    add_index :tables, :floor_plan_zone_id
    add_index :tables, [:floor_plan_zone_id, :table_number], unique: true
    add_index :tables, :table_type
    add_index :tables, :is_active
    add_index :tables, :is_bookable
    
    add_index :seats, :table_id
    add_index :seats, [:table_id, :seat_number], unique: true
    
    add_index :floor_plan_elements, :floor_plan_id
    add_index :floor_plan_elements, :element_type
    add_index :floor_plan_elements, [:floor_plan_id, :display_order]
    
    # Foreign Keys
    add_foreign_key :floor_plans, :venues, on_delete: :cascade
    add_foreign_key :floor_plan_zones, :floor_plans, on_delete: :cascade
    add_foreign_key :tables, :floor_plan_zones, on_delete: :cascade
    add_foreign_key :seats, :tables, on_delete: :cascade
    add_foreign_key :floor_plan_elements, :floor_plans, on_delete: :cascade
    
    # Check constraints
    add_check_constraint :floor_plans, "status IN ('draft', 'active', 'archived')", name: 'check_floor_plan_status'
    add_check_constraint :floor_plans, "width > 0 AND height > 0", name: 'check_floor_plan_dimensions'
    add_check_constraint :floor_plans, "venue_type IN ('restaurant', 'pub', 'bar', 'casino', 'gaming', 'sports', 'club', 'lounge', 'cafe', 'other')", name: 'check_floor_plan_venue_type'
    
    add_check_constraint :floor_plan_zones, "zone_type IN ('dining', 'bar', 'vip', 'outdoor', 'stage', 'dance_floor', 'gaming', 'other')", name: 'check_zone_type'
    add_check_constraint :floor_plan_zones, "capacity IS NULL OR capacity > 0", name: 'check_zone_capacity'
    
    add_check_constraint :tables, "table_type IN ('standard', 'booth', 'bar_stool', 'highchair', 'vip', 'counter', 'standing', 'gaming', 'other')", name: 'check_table_type'
    add_check_constraint :tables, "shape IN ('rectangle', 'circle', 'square', 'oval', 'custom')", name: 'check_table_shape'
    add_check_constraint :tables, "min_capacity > 0 AND max_capacity > 0 AND max_capacity >= min_capacity", name: 'check_table_capacity'
    add_check_constraint :tables, "width > 0 AND height > 0", name: 'check_table_dimensions'
    
    add_check_constraint :seats, "seat_number > 0", name: 'check_seat_number'
    add_check_constraint :seats, "seat_type IN ('standard', 'highchair', 'wheelchair', 'bar_stool', 'bench', 'other')", name: 'check_seat_type'
    
    add_check_constraint :floor_plan_elements, "element_type IN ('wall', 'door', 'window', 'pillar', 'decor', 'bar', 'stage', 'entrance', 'exit', 'restroom', 'kitchen', 'other')", name: 'check_element_type'
  end
end

