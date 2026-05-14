# frozen_string_literal: true

module Api
  module V1
    module Admin
      class UsersController < ApplicationController
        before_action :require_authentication!
        before_action :require_admin!
        before_action :set_user, only: [:show, :update, :update_role, :activate, :deactivate, :promote_admin, :demote_admin, :destroy]

        # GET /api/v1/admin/users
        def index
          scope = User.all

          scope = scope.where(role: Array(params[:role])) if params[:role].present?
          scope = scope.where(status: Array(params[:status])) if params[:status].present?
          scope = scope.admins if params[:admins_only].to_s == 'true'

          if params[:q].present? || params[:search].present?
            term = (params[:q] || params[:search]).to_s.strip
            q = "%#{term}%"
            scope = scope.where(
              'name ILIKE ? OR username ILIKE ? OR email ILIKE ? OR phone ILIKE ?',
              q, q, q, q
            )
          end

          page, per_page, offset = pagination_params(default_per_page: 20, max_per_page: 100)
          total_count = scope.count
          total_pages = (total_count.to_f / per_page).ceil
          users = scope.order(created_at: :desc).limit(per_page).offset(offset)

          api_success(
            data: {
              users: users.map { |u| admin_user_response(u) },
              pagination: pagination_meta(page, per_page, total_count, total_pages)
            },
            status: :ok
          )
        end

        # GET /api/v1/admin/users/:id
        def show
          api_success(data: { user: admin_user_response(@user, detailed: true) }, status: :ok)
        end

        # PATCH /api/v1/admin/users/:id
        def update
          if @user.update(admin_user_params)
            api_success(
              data: { user: admin_user_response(@user.reload, detailed: true) },
              message: 'User updated',
              status: :ok
            )
          else
            api_validation_error(errors: @user.errors.full_messages)
          end
        end

        # PATCH /api/v1/admin/users/:id/role
        def update_role
          role = params[:role].to_s
          unless %w[user owner admin].include?(role)
            api_error(message: 'Invalid role. Allowed: user, owner, admin', status: :bad_request)
            return
          end

          if @user.update(role: role)
            api_success(
              data: { user: admin_user_response(@user.reload, detailed: true) },
              message: "Role updated to #{role}",
              status: :ok
            )
          else
            api_validation_error(errors: @user.errors.full_messages)
          end
        end

        # POST /api/v1/admin/users/:id/promote_admin
        def promote_admin
          if @user.update(role: 'admin', is_admin: true)
            api_success(
              data: { user: admin_user_response(@user.reload, detailed: true) },
              message: 'User promoted to admin',
              status: :ok
            )
          else
            api_validation_error(errors: @user.errors.full_messages)
          end
        end

        # POST /api/v1/admin/users/:id/demote_admin
        def demote_admin
          if @user.id == current_user.id
            api_error(message: 'You cannot demote yourself', status: :bad_request)
            return
          end

          if @user.update(role: 'user', is_admin: false)
            api_success(
              data: { user: admin_user_response(@user.reload, detailed: true) },
              message: 'Admin privileges revoked',
              status: :ok
            )
          else
            api_validation_error(errors: @user.errors.full_messages)
          end
        end

        # POST /api/v1/admin/users/:id/activate
        def activate
          if @user.update(status: 'active')
            api_success(
              data: { user: admin_user_response(@user.reload, detailed: true) },
              message: 'User activated',
              status: :ok
            )
          else
            api_validation_error(errors: @user.errors.full_messages)
          end
        end

        # POST /api/v1/admin/users/:id/deactivate
        def deactivate
          if @user.id == current_user.id
            api_error(message: 'You cannot deactivate yourself', status: :bad_request)
            return
          end

          reason = params[:reason]
          additional_feedback = params[:additional_feedback]

          begin
            @user.deactivate!(reason: reason, additional_feedback: additional_feedback)
            api_success(
              data: { user: admin_user_response(@user.reload, detailed: true) },
              message: 'User deactivated',
              status: :ok
            )
          rescue => e
            api_error(message: e.message, status: :unprocessable_entity)
          end
        end

        # DELETE /api/v1/admin/users/:id
        def destroy
          if @user.id == current_user.id
            api_error(message: 'You cannot delete yourself', status: :bad_request)
            return
          end

          @user.destroy
          api_success(message: 'User deleted', data: { id: @user.id }, status: :ok)
        end

        # GET /api/v1/admin/dashboard/stats
        def stats
          stats = {
            users: {
              total: User.count,
              active: User.where(status: 'active').count,
              disabled: User.where(status: 'disabled').count,
              owners: User.where(role: 'owner').count,
              regular_users: User.where(role: 'user').count,
              admins: User.admins.count
            },
            properties: {
              total: Property.count,
              approved: Property.where(approval_status: 'approved').count,
              pending_review: Property.where(approval_status: 'pending_review').count,
              draft: Property.where(approval_status: 'draft').count,
              rejected: Property.where(approval_status: 'rejected').count,
              for_sale: Property.where(purpose: 'sale').count,
              for_rent: Property.where(purpose: 'rent').count,
              sold: Property.where(listing_status: 'sold').count,
              archived: Property.where(listing_status: 'archived').count
            },
            viewings: {
              total: PropertyViewing.count,
              requested: PropertyViewing.where(status: 'requested').count,
              confirmed: PropertyViewing.where(status: 'confirmed').count,
              completed: PropertyViewing.where(status: 'completed').count,
              cancelled: PropertyViewing.where(status: 'cancelled').count
            },
            favorites: {
              total: Favorite.count
            }
          }

          api_success(data: stats, status: :ok)
        end

        private

        def set_user
          @user = User.find_by(id: params[:id])
          unless @user
            api_error(message: 'User not found', status: :not_found)
            return
          end
        end

        def admin_user_params
          params.require(:user).permit(:name, :username, :email, :phone, :role, :status, :bio, :description, :address)
        end

        def pagination_meta(page, per_page, total_count, total_pages)
          {
            page: page,
            per_page: per_page,
            total_count: total_count,
            total_pages: total_pages,
            has_next_page: page < total_pages,
            has_prev_page: page > 1
          }
        end

        def admin_user_response(user, detailed: false)
          avatar = attachment_url(user.profile_picture) || user.profile_picture_url.presence || default_avatar_url

          data = {
            id: user.id,
            uniq_identifier: user.uniq_identifier,
            email: user.email,
            phone: user.phone,
            username: user.username,
            name: user.name,
            role: user.role,
            is_admin: user.is_admin,
            status: user.status,
            avatar_url: avatar,
            bio: user.bio,
            description: user.description,
            address: user.address,
            date_of_birth: user.date_of_birth,
            created_at: user.created_at,
            updated_at: user.updated_at
          }

          if detailed
            data[:stats] = {
              properties_count: Property.where(owner_id: user.id).count,
              approved_properties: Property.where(owner_id: user.id, approval_status: 'approved').count,
              favorites_count: user.favorites.count,
              viewings_count: user.property_viewings.count
            }
            active_deactivation = user.user_deactivations.active.last rescue nil
            if active_deactivation
              data[:deactivation] = {
                reason: active_deactivation.reason,
                deactivated_at: active_deactivation.deactivated_at,
                additional_feedback: active_deactivation.additional_feedback
              }
            end
          end

          data
        end
      end
    end
  end
end
