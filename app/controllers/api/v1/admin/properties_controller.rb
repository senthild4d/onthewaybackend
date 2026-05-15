# frozen_string_literal: true

module Api
  module V1
    module Admin
      class PropertiesController < ApplicationController
        include PropertySerializable

        before_action :require_authentication!
        before_action :require_admin!
        before_action :set_property, only: [:show, :approve, :reject, :archive, :unarchive, :destroy]

        # GET /api/v1/admin/properties
        def index
          scope = Property.includes(images_attachments: :blob, video_attachment: :blob, owner: { profile_picture_attachment: :blob })

          scope = scope.where(approval_status: Array(params[:approval_status])) if params[:approval_status].present?
          scope = scope.where(listing_status: Array(params[:listing_status])) if params[:listing_status].present?
          scope = scope.where(purpose: params[:purpose]) if params[:purpose].present?
          scope = scope.where(property_type: Array(params[:property_type])) if params[:property_type].present?
          scope = scope.where(owner_id: params[:owner_id]) if params[:owner_id].present?

          if params[:q].present? || params[:search].present?
            term = (params[:q] || params[:search]).to_s.strip
            q = "%#{term}%"
            scope = scope.where('title ILIKE ? OR description ILIKE ? OR city ILIKE ? OR country ILIKE ?', q, q, q, q)
          end

          page, per_page, offset = pagination_params(default_per_page: 20, max_per_page: 100)
          total_count = scope.count
          total_pages = (total_count.to_f / per_page).ceil
          properties = scope.order(created_at: :desc).limit(per_page).offset(offset)

          api_success(
            data: {
              properties: properties.map { |p| admin_property_response(p) },
              pagination: {
                page: page,
                per_page: per_page,
                total_count: total_count,
                total_pages: total_pages,
                has_next_page: page < total_pages,
                has_prev_page: page > 1
              }
            },
            status: :ok
          )
        end

        # GET /api/v1/admin/properties/:id
        def show
          api_success(data: { property: admin_property_response(@property, detailed: true) }, status: :ok)
        end

        # POST /api/v1/admin/properties/:id/approve
        def approve
          @property.approve!(by: current_user)
          notify_owner(@property, 'Property Approved', "Your property \"#{@property.title}\" has been approved.")
          api_success(data: { property: admin_property_response(@property.reload, detailed: true) }, message: 'Property approved', status: :ok)
        end

        # POST /api/v1/admin/properties/:id/reject
        def reject
          reason = params[:reason].to_s
          if reason.blank?
            api_error(message: 'reason is required', status: :bad_request)
            return
          end

          @property.reject!(by: current_user, reason: reason)
          notify_owner(@property, 'Property Rejected', "Your property \"#{@property.title}\" was rejected. Reason: #{reason}")
          api_success(data: { property: admin_property_response(@property.reload, detailed: true) }, message: 'Property rejected', status: :ok)
        end

        # POST /api/v1/admin/properties/:id/archive
        def archive
          @property.archive!(by: current_user)
          api_success(data: { property: admin_property_response(@property.reload, detailed: true) }, message: 'Property archived', status: :ok)
        end

        # POST /api/v1/admin/properties/:id/unarchive
        def unarchive
          @property.unarchive!
          api_success(data: { property: admin_property_response(@property.reload, detailed: true) }, message: 'Property unarchived', status: :ok)
        end

        # DELETE /api/v1/admin/properties/:id
        def destroy
          @property.destroy
          api_success(message: 'Property deleted', data: { id: @property.id }, status: :ok)
        end

        private

        def set_property
          @property = Property.find_by(id: params[:id])
          unless @property
            api_error(message: 'Property not found', status: :not_found)
            return
          end
        end

        def notify_owner(property, title, body)
          return unless property.owner.present?
          NotificationService.send_to_user(
            property.owner,
            title: title,
            body: body,
            data: { type: 'property_update', property_id: property.id.to_s }
          )
        rescue => e
          Rails.logger.error "Failed to notify owner: #{e.message}"
        end

        def admin_property_response(property, detailed: false)
          video_url = attachment_url(property.video)

          data = {
            id: property.id,
            title: property.title,
            description: property.description,
            property_type: property.property_type,
            purpose: property.purpose,
            bedrooms: property.bedrooms,
            bathrooms: property.bathrooms,
            area_sqft: property.area_sqft,
            area_sqm: property.area_sqm,
            price: property.price,
            currency: property.currency,
            approval_status: property.approval_status,
            listing_status: property.listing_status,
            features: property.normalized_features,
            address: {
              address1: property.address1,
              address2: property.address2,
              city: property.city,
              region: property.region,
              postal_code: property.postal_code,
              country: property.country,
              full_address: property.full_address
            },
            coordinates: property.coordinates? ? { latitude: property.latitude.to_f, longitude: property.longitude.to_f } : nil,
            images: property_images_response(property),
            video: video_url,
            submitted_at: property.submitted_at&.iso8601,
            approved_at: property.approved_at&.iso8601,
            rejected_at: property.rejected_at&.iso8601,
            rejection_reason: property.rejection_reason,
            sold_at: property.sold_at&.iso8601,
            archived_at: property.archived_at&.iso8601,
            created_at: property.created_at&.iso8601,
            updated_at: property.updated_at&.iso8601,
            owner: property.owner ? {
              id: property.owner.id,
              name: property.owner.name,
              email: property.owner.email,
              phone: property.owner.phone
            } : nil
          }

          data
        end
      end
    end
  end
end
