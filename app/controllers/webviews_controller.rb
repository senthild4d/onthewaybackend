class WebviewsController < ActionController::Base
  
  # Skip CSRF token verification for API-like access
  skip_before_action :verify_authenticity_token
  
  # GET /webviews/venues/:venue_id/floor_plans/:id
  # Returns HTML page for WebView embedding using Konva.js
  def floor_plan
    venue = Venue.find_by(id: params[:venue_id])
    unless venue
      render plain: 'Venue not found', status: :not_found
      return
    end
    
    floor_plan = venue.floor_plans.includes(
      floor_plan_zones: { tables: :seats },
      floor_plan_elements: []
    ).find_by(id: params[:id])
    
    unless floor_plan
      render plain: 'Floor plan not found', status: :not_found
      return
    end
    
    @floor_plan = floor_plan
    @venue = venue
    @canvas_data = floor_plan.to_canvas_json
    @venue_data = {
      id: venue.id,
      name: venue.name,
      capacity: venue.capacity
    }
    @auth_token = params[:auth_token].presence || params[:token].presence
    
    # Set response headers
    response.headers['Content-Type'] = 'text/html; charset=utf-8'
    response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
    
    # Render the template
    render template: 'webviews/floor_plan', layout: false
  rescue ActiveRecord::RecordNotFound => e
    render plain: e.message, status: :not_found
  rescue => e
    Rails.logger.error "Webview error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render plain: 'Error loading floor plan', status: :internal_server_error
  end

  # GET /webviews/venues/:venue_id/floor_plans/:id/select
  # Returns HTML page for selecting a table/seat in WebView
  def floor_plan_select
    venue = Venue.find_by(id: params[:venue_id])
    unless venue
      render plain: 'Venue not found', status: :not_found
      return
    end

    floor_plan = venue.floor_plans.includes(
      floor_plan_zones: { tables: :seats },
      floor_plan_elements: []
    ).find_by(id: params[:id])

    unless floor_plan
      render plain: 'Floor plan not found', status: :not_found
      return
    end

    @floor_plan = floor_plan
    @venue = venue
    @canvas_data = floor_plan.to_canvas_json
    @venue_data = {
      id: venue.id,
      name: venue.name,
      capacity: venue.capacity
    }
    @auth_token = params[:auth_token].presence || params[:token].presence
    @booking_id = params[:booking_id].presence || params[:booking].presence
    @auto_assign = params[:auto_assign].to_s == 'true'
    @event_id = params[:event_id]

    response.headers['Content-Type'] = 'text/html; charset=utf-8'
    response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'

    render template: 'webviews/floor_plan_select', layout: false
  rescue ActiveRecord::RecordNotFound => e
    render plain: e.message, status: :not_found
  rescue => e
    Rails.logger.error "Webview error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render plain: 'Error loading floor plan', status: :internal_server_error
  end
end

