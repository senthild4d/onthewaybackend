module Api
  module V1
    class FloorPlansController < ApplicationController
      before_action :require_authentication!
      before_action :set_venue
      before_action :check_venue_ownership, except: [:index, :show, :canvas]
      before_action :set_floor_plan, only: [:show, :update, :destroy, :activate, :duplicate]
      
      # GET /api/v1/venues/:venue_id/floor_plans
      def index
        floor_plans = @venue.floor_plans.includes(:floor_plan_zones, :floor_plan_elements)
        
        # Filter by status
        floor_plans = floor_plans.where(status: params[:status]) if params[:status].present?
        
        # Filter by venue type
        floor_plans = floor_plans.where(venue_type: params[:venue_type]) if params[:venue_type].present?
        
        unless can_manage_venue?
          floor_plans = floor_plans.where(status: 'active')
        end

        floor_plans = floor_plans.order(is_default: :desc, created_at: :desc)
        
        api_success(
          data: {
            floor_plans: floor_plans.map { |fp| floor_plan_summary(fp) },
            venue_id: @venue.id,
            venue_name: @venue.name
          },
          status: :ok
        )
      end
      
      # GET /api/v1/venues/:venue_id/floor_plans/:id
      def show
        unless can_manage_venue?
          unless @floor_plan.status == 'active'
            api_error(message: 'Floor plan not found', status: :not_found)
            return
          end
        end

        api_success(
          data: { 
            floor_plan: floor_plan_detailed(@floor_plan),
            venue_id: @venue.id,
            venue_name: @venue.name
          },
          status: :ok
        )
      end
      
      # GET /api/v1/venues/:venue_id/floor_plans/:id/canvas
      # Returns floor plan data in canvas-ready JSON format for WebView
      def canvas
        @floor_plan = @venue.floor_plans.includes(
          floor_plan_zones: { tables: :seats },
          floor_plan_elements: []
        ).find(params[:id])

        unless can_manage_venue?
          unless @floor_plan.status == 'active'
            api_error(message: 'Floor plan not found', status: :not_found)
            return
          end
        end
        
        api_success(
          data: {
            canvas: @floor_plan.to_canvas_json,
            venue: {
              id: @venue.id,
              name: @venue.name,
              capacity: @venue.capacity
            }
          },
          status: :ok
        )
      rescue ActiveRecord::RecordNotFound
        api_error(message: 'Floor plan not found', status: :not_found)
      end
      
      # POST /api/v1/venues/:venue_id/floor_plans
      def create
        floor_plan = @venue.floor_plans.build(floor_plan_params)
        
        if floor_plan.save
          api_success(
            data: { floor_plan: floor_plan_detailed(floor_plan) },
            message: 'Floor plan created successfully',
            status: :created
          )
        else
          api_validation_error(errors: floor_plan.errors.full_messages)
        end
      end
      
      # PATCH/PUT /api/v1/venues/:venue_id/floor_plans/:id
      def update
        if @floor_plan.update(floor_plan_params)
          api_success(
            data: { floor_plan: floor_plan_detailed(@floor_plan) },
            message: 'Floor plan updated successfully',
            status: :ok
          )
        else
          api_validation_error(errors: @floor_plan.errors.full_messages)
        end
      end
      
      # DELETE /api/v1/venues/:venue_id/floor_plans/:id
      def destroy
        if @floor_plan.is_default?
          api_error(
            message: 'Cannot delete the default floor plan. Set another floor plan as default first.',
            status: :unprocessable_entity
          )
          return
        end
        
        if @floor_plan.destroy
          api_success(message: 'Floor plan deleted successfully', status: :ok)
        else
          api_validation_error(errors: @floor_plan.errors.full_messages)
        end
      end
      
      # POST /api/v1/venues/:venue_id/floor_plans/:id/activate
      # Sets this floor plan as the active/default floor plan
      def activate
        @floor_plan.update!(is_default: true, status: 'active')
        
        api_success(
          data: { floor_plan: floor_plan_summary(@floor_plan) },
          message: 'Floor plan activated successfully',
          status: :ok
        )
      rescue ActiveRecord::RecordInvalid => e
        api_validation_error(errors: e.record.errors.full_messages)
      end
      
      # POST /api/v1/venues/:venue_id/floor_plans/:id/duplicate
      # Duplicates an existing floor plan
      def duplicate
        new_floor_plan = @floor_plan.dup
        new_floor_plan.name = "#{@floor_plan.name} (Copy)"
        new_floor_plan.is_default = false
        new_floor_plan.status = 'draft'
        
        ActiveRecord::Base.transaction do
          new_floor_plan.save!
          
          # Duplicate zones
          @floor_plan.floor_plan_zones.each do |zone|
            new_zone = zone.dup
            new_zone.floor_plan = new_floor_plan
            new_zone.save!
            
            # Duplicate tables
            zone.tables.each do |table|
              new_table = table.dup
              new_table.floor_plan_zone = new_zone
              new_table.save!
              
              # Duplicate seats
              table.seats.each do |seat|
                new_seat = seat.dup
                new_seat.table = new_table
                new_seat.save!
              end
            end
          end
          
          # Duplicate elements
          @floor_plan.floor_plan_elements.each do |element|
            new_element = element.dup
            new_element.floor_plan = new_floor_plan
            new_element.save!
          end
        end
        
        api_success(
          data: { floor_plan: floor_plan_detailed(new_floor_plan) },
          message: 'Floor plan duplicated successfully',
          status: :created
        )
      rescue ActiveRecord::RecordInvalid => e
        api_validation_error(errors: e.record.errors.full_messages)
      end
      
      # POST /api/v1/venues/:venue_id/floor_plans/:id/zones
      # Add a zone to the floor plan
      def create_zone
        @floor_plan = @venue.floor_plans.find(floor_plan_param_id)
        zone = @floor_plan.floor_plan_zones.build(zone_params)
        
        if zone.save
          api_success(
            data: { zone: zone_response(zone) },
            message: 'Zone created successfully',
            status: :created
          )
        else
          api_validation_error(errors: zone.errors.full_messages)
        end
      rescue ActiveRecord::RecordNotFound
        api_error(message: 'Floor plan not found', status: :not_found)
      end
      
      # PATCH /api/v1/venues/:venue_id/floor_plans/:id/zones/:zone_id
      def update_zone
        @floor_plan = @venue.floor_plans.find(floor_plan_param_id)
        zone = @floor_plan.floor_plan_zones.find(params[:zone_id])
        
        if zone.update(zone_params)
          api_success(
            data: { zone: zone_response(zone) },
            message: 'Zone updated successfully',
            status: :ok
          )
        else
          api_validation_error(errors: zone.errors.full_messages)
        end
      rescue ActiveRecord::RecordNotFound => e
        api_error(message: e.message, status: :not_found)
      end
      
      # DELETE /api/v1/venues/:venue_id/floor_plans/:id/zones/:zone_id
      def destroy_zone
        @floor_plan = @venue.floor_plans.find(floor_plan_param_id)
        zone = @floor_plan.floor_plan_zones.find(params[:zone_id])
        
        if zone.destroy
          api_success(message: 'Zone deleted successfully', status: :ok)
        else
          api_error(message: 'Failed to delete zone', status: :internal_server_error)
        end
      rescue ActiveRecord::RecordNotFound => e
        api_error(message: e.message, status: :not_found)
      end
      
      # POST /api/v1/venues/:venue_id/floor_plans/:id/zones/:zone_id/tables
      def create_table
        @floor_plan = @venue.floor_plans.find(floor_plan_param_id)
        zone = @floor_plan.floor_plan_zones.find(params[:zone_id])
        table = zone.tables.build(table_params)
        
        if table.save
          # Auto-create seats if seat_positions provided
          if params[:seat_positions].present?
            params[:seat_positions].each_with_index do |seat_pos, index|
              table.seats.create!(
                seat_number: index + 1,
                x_position: seat_pos[:x],
                y_position: seat_pos[:y],
                position_label: seat_pos[:label],
                seat_type: seat_pos[:type] || 'standard'
              )
            end
          end
          
          api_success(
            data: { table: table_response(table) },
            message: 'Table created successfully',
            status: :created
          )
        else
          api_validation_error(errors: table.errors.full_messages)
        end
      rescue ActiveRecord::RecordNotFound => e
        api_error(message: e.message, status: :not_found)
      end
      
      # PATCH /api/v1/venues/:venue_id/floor_plans/:id/tables/:table_id
      def update_table
        @floor_plan = @venue.floor_plans.find(floor_plan_param_id)
        table = @floor_plan.tables.find(params[:table_id])
        
        if table.update(table_params)
          api_success(
            data: { table: table_response(table) },
            message: 'Table updated successfully',
            status: :ok
          )
        else
          api_validation_error(errors: table.errors.full_messages)
        end
      rescue ActiveRecord::RecordNotFound => e
        api_error(message: e.message, status: :not_found)
      end
      
      # DELETE /api/v1/venues/:venue_id/floor_plans/:id/tables/:table_id
      def destroy_table
        @floor_plan = @venue.floor_plans.find(floor_plan_param_id)
        table = @floor_plan.tables.find(params[:table_id])
        
        if table.destroy
          api_success(message: 'Table deleted successfully', status: :ok)
        else
          api_error(message: 'Failed to delete table', status: :internal_server_error)
        end
      rescue ActiveRecord::RecordNotFound => e
        api_error(message: e.message, status: :not_found)
      end
      
      # POST /api/v1/venues/:venue_id/floor_plans/:id/elements
      def create_element
        @floor_plan = @venue.floor_plans.find(floor_plan_param_id)
        element = @floor_plan.floor_plan_elements.build(element_params)
        
        if element.save
          api_success(
            data: { element: element_response(element) },
            message: 'Element created successfully',
            status: :created
          )
        else
          api_validation_error(errors: element.errors.full_messages)
        end
      rescue ActiveRecord::RecordNotFound
        api_error(message: 'Floor plan not found', status: :not_found)
      end
      
      # PATCH /api/v1/venues/:venue_id/floor_plans/:id/elements/:element_id
      def update_element
        @floor_plan = @venue.floor_plans.find(floor_plan_param_id)
        element = @floor_plan.floor_plan_elements.find(params[:element_id])
        
        if element.update(element_params)
          api_success(
            data: { element: element_response(element) },
            message: 'Element updated successfully',
            status: :ok
          )
        else
          api_validation_error(errors: element.errors.full_messages)
        end
      rescue ActiveRecord::RecordNotFound => e
        api_error(message: e.message, status: :not_found)
      end
      
      # DELETE /api/v1/venues/:venue_id/floor_plans/:id/elements/:element_id
      def destroy_element
        @floor_plan = @venue.floor_plans.find(floor_plan_param_id)
        element = @floor_plan.floor_plan_elements.find(params[:element_id])
        
        if element.destroy
          api_success(message: 'Element deleted successfully', status: :ok)
        else
          api_error(message: 'Failed to delete element', status: :internal_server_error)
        end
      rescue ActiveRecord::RecordNotFound => e
        api_error(message: e.message, status: :not_found)
      end
      
      private
      
      def set_venue
        @venue = Venue.find_by(id: params[:venue_id])
        unless @venue
          api_error(message: 'Venue not found', status: :not_found)
          return
        end
      end
      
      def check_venue_ownership
        unless can_manage_venue?
          api_error(message: 'You can only modify floor plans for your own venues', status: :forbidden)
          return
        end
      end

      def can_manage_venue?
        @venue.owner_id == current_user.id || current_user.role_admin?
      end
      
      def set_floor_plan
        @floor_plan = @venue.floor_plans.find_by(id: params[:id])
        unless @floor_plan
          api_error(message: 'Floor plan not found', status: :not_found)
          return
        end
      end

      def floor_plan_param_id
        params[:floor_plan_id].presence || params[:id]
      end
      
      def floor_plan_params
        params.require(:floor_plan).permit(
          :name,
          :description,
          :venue_type,
          :width,
          :height,
          :scale_factor,
          :thumbnail_url,
          :status,
          :is_default,
          settings: {}
        )
      end
      
      def zone_params
        params.require(:zone).permit(
          :name,
          :zone_type,
          :color,
          :capacity,
          :is_bookable,
          :is_active,
          :min_spend,
          :display_order,
          geometry: {}
        )
      end
      
      def table_params
        params.require(:table).permit(
          :table_number,
          :table_name,
          :table_type,
          :shape,
          :x_position,
          :y_position,
          :width,
          :height,
          :rotation,
          :min_capacity,
          :max_capacity,
          :is_accessible,
          :is_active,
          :is_bookable,
          :color,
          custom_properties: {}
        )
      end
      
      def element_params
        params.require(:element).permit(
          :element_type,
          :name,
          :color,
          :rotation,
          :is_visible,
          :display_order,
          geometry: {},
          properties: {}
        )
      end
      
      def floor_plan_summary(floor_plan)
        {
          id: floor_plan.id,
          name: floor_plan.name,
          description: floor_plan.description,
          venue_type: floor_plan.venue_type,
          dimensions: {
            width: floor_plan.width,
            height: floor_plan.height
          },
          scale_factor: floor_plan.scale_factor,
          status: floor_plan.status,
          is_default: floor_plan.is_default,
          thumbnail_url: floor_plan.thumbnail_url,
          stats: {
            total_zones: floor_plan.floor_plan_zones.count,
            total_tables: floor_plan.total_tables,
            total_seats: floor_plan.total_seats,
            total_capacity: floor_plan.total_capacity,
            bookable_tables: floor_plan.bookable_tables_count
          },
          created_at: floor_plan.created_at,
          updated_at: floor_plan.updated_at
        }
      end
      
      def floor_plan_detailed(floor_plan)
        floor_plan_summary(floor_plan).merge({
          settings: floor_plan.settings,
          zones: floor_plan.floor_plan_zones.order(:display_order).map { |z| zone_response(z) },
          elements: floor_plan.floor_plan_elements.order(:display_order).map { |e| element_response(e) }
        })
      end
      
      def zone_response(zone)
        {
          id: zone.id,
          name: zone.name,
          zone_type: zone.zone_type,
          geometry: zone.geometry,
          color: zone.color,
          capacity: zone.capacity,
          is_bookable: zone.is_bookable,
          is_active: zone.is_active,
          min_spend: zone.min_spend,
          display_order: zone.display_order,
          stats: {
            total_tables: zone.total_tables,
            available_tables: zone.available_tables.count
          },
          tables: zone.tables.includes(:seats).map { |t| table_response(t) }
        }
      end
      
      def table_response(table)
        {
          id: table.id,
          table_number: table.table_number,
          table_name: table.table_name,
          full_name: table.full_name,
          table_type: table.table_type,
          shape: table.shape,
          position: {
            x: table.x_position,
            y: table.y_position
          },
          dimensions: {
            width: table.width,
            height: table.height
          },
          rotation: table.rotation,
          capacity: {
            min: table.min_capacity,
            max: table.max_capacity
          },
          is_accessible: table.is_accessible,
          is_active: table.is_active,
          is_bookable: table.is_bookable,
          color: table.color,
          custom_properties: table.custom_properties,
          seats: table.seats.order(:seat_number).map { |s| seat_response(s) }
        }
      end
      
      def seat_response(seat)
        {
          id: seat.id,
          seat_number: seat.seat_number,
          position: {
            x: seat.x_position,
            y: seat.y_position
          },
          position_label: seat.position_label,
          seat_type: seat.seat_type,
          is_active: seat.is_active,
          is_accessible: seat.is_accessible
        }
      end
      
      def element_response(element)
        {
          id: element.id,
          element_type: element.element_type,
          name: element.name,
          geometry: element.geometry,
          color: element.color,
          rotation: element.rotation,
          properties: element.properties,
          is_visible: element.is_visible,
          display_order: element.display_order
        }
      end
    end
  end
end

