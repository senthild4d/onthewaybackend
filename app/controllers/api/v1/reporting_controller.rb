module Api
  module V1
    class ReportingController < ApplicationController
      before_action :require_authentication!
      before_action :require_admin!, except: [:my_reports]
      
      # GET /api/v1/reporting
      def index
        reports = EventReport.includes(:event, :reporter, :reviewed_by)
        
        # Filter by status
        reports = reports.where(status: params[:status]) if params[:status].present?
        
        # Filter by reason
        reports = reports.where(reason: params[:reason]) if params[:reason].present?
        
        # Filter by event
        reports = reports.where(event_id: params[:event_id]) if params[:event_id].present?
        
        # Sort
        sort_by = params[:sort_by] || 'created_at'
        sort_order = params[:sort_order] || 'desc'
        reports = reports.order("#{sort_by} #{sort_order}")
        
        # Pagination
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = reports.count
        reports = reports.limit(limit).offset(offset)
        
        api_success(
          data: {
            reports: reports.map { |report| report_response(report) },
            pagination: {
              limit: limit,
              offset: offset,
              total_count: total_count,
              has_more: (offset + limit) < total_count
            }
          },
          status: :ok
        )
      end
      
      # GET /api/v1/reporting/:id
      def show
        report = EventReport.includes(:event, :reporter, :reviewed_by).find_by(id: params[:id])
        
        unless report
          api_error(message: 'Report not found', status: :not_found)
          return
        end
        
        api_success(
          data: { report: report_response(report, detailed: true) },
          status: :ok
        )
      end
      
      # PATCH /api/v1/reporting/:id/review
      def review
        report = EventReport.find_by(id: params[:id])
        
        unless report
          api_error(message: 'Report not found', status: :not_found)
          return
        end
        
        status = params[:status]
        admin_notes = params[:admin_notes]
        
        unless EventReport.statuses.keys.include?(status)
          api_error(message: "Invalid status. Must be one of: #{EventReport.statuses.keys.join(', ')}", status: :bad_request)
          return
        end
        
        report.review!(current_user, status: status, admin_notes: admin_notes)
        
        api_success(
          data: { report: report_response(report, detailed: true) },
          message: 'Report reviewed successfully',
          status: :ok
        )
      rescue => e
        Rails.logger.error "Review Report Error: #{e.message}"
        api_error(message: 'Failed to review report', status: :internal_server_error)
      end
      
      # GET /api/v1/reporting/my_reports
      def my_reports
        reports = current_user.event_reports.includes(:event, :reviewed_by)
        
        # Filter by status
        reports = reports.where(status: params[:status]) if params[:status].present?
        
        # Sort
        sort_by = params[:sort_by] || 'created_at'
        sort_order = params[:sort_order] || 'desc'
        reports = reports.order("#{sort_by} #{sort_order}")
        
        # Pagination
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        total_count = reports.count
        reports = reports.limit(limit).offset(offset)
        
        api_success(
          data: {
            reports: reports.map { |report| report_response(report) },
            pagination: {
              limit: limit,
              offset: offset,
              total_count: total_count,
              has_more: (offset + limit) < total_count
            }
          },
          status: :ok
        )
      end
      
      private
      
      def require_admin!
        unless current_user.role_admin?
          api_error(message: 'Admin access required', status: :forbidden)
          return
        end
      end
      
      def report_response(report, detailed: false)
        response = {
          id: report.id,
          event: {
            id: report.event.id,
            title: report.event.title,
            venue: {
              id: report.event.venue.id,
              name: report.event.venue.name
            }
          },
          reporter: {
            id: report.reporter.id,
            name: report.reporter.name,
            username: report.reporter.username
          },
          reason: report.reason,
          description: report.description,
          status: report.status,
          created_at: report.created_at
        }
        
        if detailed
          response.merge!(
            reviewed_by: report.reviewed_by ? {
              id: report.reviewed_by.id,
              name: report.reviewed_by.name,
              username: report.reviewed_by.username
            } : nil,
            admin_notes: report.admin_notes,
            reviewed_at: report.reviewed_at,
            updated_at: report.updated_at
          )
        end
        
        response
      end
    end
  end
end

