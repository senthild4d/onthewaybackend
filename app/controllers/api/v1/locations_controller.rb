module Api
  module V1
    class LocationsController < ApplicationController
      before_action :require_authentication!
      before_action :set_manager

      # GET /api/v1/location
      def show
        snapshot = @manager.current_location
        api_success(data: { location: snapshot.as_json })
      end

      # POST /api/v1/location/device
      def device
        snapshot = @manager.record_device_location(location_params)
        
        # Auto-add user to city-based group chats
        city_manager = CityGroupChatManager.new(current_user)
        city_manager.add_user_to_city_groups
        
        api_success(data: { location: snapshot.as_json }, message: 'Device location updated')
      rescue UserLocationManager::ValidationError => e
        api_validation_error(errors: e.errors)
      end

      # POST /api/v1/location/manual
      def manual
        snapshot = @manager.record_manual_location(location_params)
        
        # Auto-add user to city-based group chats
        city_manager = CityGroupChatManager.new(current_user)
        city_manager.add_user_to_city_groups
        
        api_success(data: { location: snapshot.as_json }, message: 'Manual location updated')
      rescue UserLocationManager::ValidationError => e
        api_validation_error(errors: e.errors)
      end

      # POST /api/v1/location/reset
      def reset
        snapshot = @manager.reset!
        api_success(data: { location: snapshot.as_json }, message: 'Location reset. Awaiting device update')
      end

      private

      def set_manager
        @manager = UserLocationManager.new(current_user)
      end

      def location_params
        params.require(:location).permit(:lat, :lng, :formatted_address, :place_id)
      end
    end
  end
end

