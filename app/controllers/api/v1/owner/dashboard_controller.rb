# frozen_string_literal: true

module Api
  module V1
    module Owner
      class DashboardController < ApplicationController
        before_action :require_authentication!
        before_action :require_property_owner!

        # GET /api/v1/owner/dashboard_summary
        # Legacy: GET /api/v1/venue_manager/dashboard_summary
        def summary
          data = OwnerDashboardService.new(current_user).summary
          api_success(data: data, status: :ok)
        end

        # GET /api/v1/owner/dashboard_metrics?period=monthly
        # Legacy: GET /api/v1/venue_manager/dashboard_metrics?period=monthly
        # (replaces venues/:venue_id/manager/dashboard_metrics — not venue-scoped)
        def metrics
          period = params[:period].presence || 'monthly'
          data = OwnerDashboardService.new(current_user).metrics(period: period)
          api_success(data: data, status: :ok)
        end

        private

        def require_property_owner!
          return if current_user.admin?
          return if current_user.role_owner?
          return if current_user.owned_properties.exists?

          api_error(message: 'Only property owners can access this dashboard', status: :forbidden)
          false
        end
      end
    end
  end
end
