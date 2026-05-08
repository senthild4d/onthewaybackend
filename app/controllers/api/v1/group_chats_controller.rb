module Api
  module V1
    class GroupChatsController < ApplicationController
      before_action :require_authentication!
      before_action :set_group_chat, only: [:show, :update, :destroy, :add_member, :remove_member, :list_members, :available_users, :leave, :mute, :unmute, :pin, :unpin, :star, :unstar, :archive, :unarchive, :invite_qr, :invite_url, :regenerate_invite, :join_by_code]
      before_action :check_group_chat_membership, only: [:show, :update, :list_members, :available_users, :leave, :mute, :unmute, :pin, :unpin, :star, :unstar, :archive, :unarchive, :invite_qr, :invite_url]
      before_action :check_group_chat_admin, only: [:update, :destroy, :add_member, :remove_member, :available_users, :regenerate_invite]
      before_action :check_group_chat_owner, only: [:destroy]

      # GET /api/v1/group_chats
      def index
        # Get user's group chats
        user_group_chats = current_user.group_chats.active.includes(:created_by, :members)
        
        # If user has location, also include city-based groups they should see
        city_group_chat_ids = []
        if params[:include_city_groups] != 'false'
          location_data = current_user.current_location
          if location_data.present?
            city_manager = CityGroupChatManager.new(current_user)
            city_info = city_manager.extract_city_from_location(location_data)
            
            if city_info.present?
              # Find city-based groups for user's city
              city_groups = GroupChat.city_based.by_city(city_info[:city], city_info[:country])
                                     .active
                                     .pluck(:id)
              
              city_group_chat_ids = city_groups
            end
          end
        end
        
        # Combine user's groups with city-based groups (avoid duplicates)
        all_group_chat_ids = (user_group_chats.pluck(:id) + city_group_chat_ids).uniq
        
        # Build query with proper sorting
        group_chats_query = GroupChat.where(id: all_group_chat_ids)
                                     .active
                                     .includes(:created_by, :members)
        
        # Get total count before sorting
        total_count = group_chats_query.count
        
        # Get memberships for sorting
        memberships = GroupChatMembership.where(group_chat_id: all_group_chat_ids, user_id: current_user.id)
        pinned_ids = memberships.where(is_pinned: true).pluck(:group_chat_id)
        starred_ids = memberships.where(is_starred: true).pluck(:group_chat_id)
        
        # Sort: pinned first, then starred, then city-based, then by last_message_at
        all_group_chats = group_chats_query.to_a.sort_by do |gc|
          [
            pinned_ids.include?(gc.id) ? 0 : 1, # Pinned first
            starred_ids.include?(gc.id) ? 0 : 1, # Starred second
            city_group_chat_ids.include?(gc.id) ? 0 : 1, # City-based third
            -(gc.last_message_at || gc.created_at).to_i # Most recent last
          ]
        end
        
        # Apply pagination
        limit = [params[:limit]&.to_i || 20, 100].min
        offset = params[:offset]&.to_i || 0
        group_chats = all_group_chats[offset, limit] || []
        
        api_success(
          data: {
            group_chats: group_chats.map { |group_chat| group_chat_response(group_chat) },
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

      # GET /api/v1/group_chats/:id
      def show
        api_success(
          data: {
            group_chat: group_chat_response(@group_chat, include_members: true)
          },
          status: :ok
        )
      end

      # GET /api/v1/group_chats/:id/members
      # List all members of a group chat
      def list_members
        members = @group_chat.members.includes(:group_chat_memberships)
        
        # Filter by role if provided
        if params[:role].present?
          role = params[:role].downcase
          if ['owner', 'admin', 'member'].include?(role)
            members = members.joins(:group_chat_memberships)
                            .where(group_chat_memberships: { role: role })
          end
        end
        
        # Search by name or username if provided
        if params[:search].present?
          search_term = "%#{params[:search]}%"
          members = members.where("name ILIKE ? OR username ILIKE ?", search_term, search_term)
        end
        
        # Sort members (owner first, then admin, then member, then by joined_at)
        # Use Arel.sql to mark raw SQL as safe for ORDER BY (Rails 7+ safety check).
        role_order_sql = Arel.sql(<<~SQL.squish)
          CASE group_chat_memberships.role
            WHEN 'owner' THEN 1
            WHEN 'admin' THEN 2
            WHEN 'member' THEN 3
            ELSE 4
          END
        SQL

        joined_at_order_sql = Arel.sql('group_chat_memberships.joined_at ASC')

        # Note: each user has at most one membership per group (validated in GroupChatMembership),
        # so we don't need DISTINCT here. Keeping DISTINCT with a custom ORDER BY on joined table
        # columns causes PostgreSQL to raise \"ORDER BY expressions must appear in select list\".
        members = members.joins(:group_chat_memberships)
                         .order(role_order_sql, joined_at_order_sql)
        
        # Pagination
        limit = [params[:limit]&.to_i || 50, 200].min
        offset = params[:offset]&.to_i || 0
        total_count = members.count
        members = members.limit(limit).offset(offset)
        
        api_success(
          data: {
            group_chat_id: @group_chat.id,
            group_chat_name: @group_chat.name,
            members: members.map do |member|
              membership = @group_chat.group_chat_memberships.find_by(user: member)
              {
                id: member.id,
                name: member.name,
                username: member.username,
                avatar_url: member.avatar_url,
                role: membership.role,
                joined_at: membership.joined_at.iso8601
              }
            end,
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

      # POST /api/v1/group_chats
      def create
        group_chat = current_user.created_group_chats.build(group_chat_params)
        
        if group_chat.save
          # Add initial members if provided
          if params[:member_ids].present?
            params[:member_ids].each do |user_id|
              user = User.find_by(id: user_id)
              group_chat.add_member(user) if user && user != current_user
            end
          end
          
          api_success(
            data: { group_chat: group_chat_response(group_chat, include_members: true) },
            message: 'Group chat created successfully',
            status: :created
          )
        else
          api_validation_error(errors: group_chat.errors.full_messages)
        end
      end

      # PATCH /api/v1/group_chats/:id
      def update
        if @group_chat.update(group_chat_params)
          api_success(
            data: { group_chat: group_chat_response(@group_chat, include_members: true) },
            message: 'Group chat updated successfully',
            status: :ok
          )
        else
          api_validation_error(errors: @group_chat.errors.full_messages)
        end
      end

      # DELETE /api/v1/group_chats/:id
      def destroy
        # Only owner can delete group chat
        if @group_chat.destroy
          api_success(message: 'Group chat deleted successfully', status: :ok)
        else
          api_validation_error(errors: @group_chat.errors.full_messages)
        end
      end

      # GET /api/v1/group_chats/:id/available_users
      # Get list of users that can be added to the group chat (excludes current members)
      def available_users
        # Get current member IDs to exclude
        current_member_ids = @group_chat.members.pluck(:id)
        
        # Start with all active users, excluding current members
        users = User.active.where.not(id: current_member_ids)
        
        # Exclude current user if they're already a member (shouldn't happen, but safety check)
        users = users.where.not(id: current_user.id) if current_member_ids.include?(current_user.id)
        
        # Search by name or username if provided
        if params[:search].present?
          search_term = "%#{params[:search]}%"
          users = users.where("name ILIKE ? OR username ILIKE ?", search_term, search_term)
        end
        
        # Filter by role if provided
        if params[:role].present?
          users = users.where(role: params[:role])
        end
        
        # Optional: Filter by followers/following relationships
        if params[:filter] == 'following'
          # Only show users that current user is following
          users = users.joins("INNER JOIN follows ON follows.followed_id = users.id")
                      .where(follows: { follower_id: current_user.id })
        elsif params[:filter] == 'followers'
          # Only show users that follow current user
          users = users.joins("INNER JOIN follows ON follows.follower_id = users.id")
                      .where(follows: { followed_id: current_user.id })
        elsif params[:filter] == 'mutual'
          # Only show users that current user follows AND who follow back
          following_ids = current_user.following.pluck(:id)
          followers_ids = current_user.followers.pluck(:id)
          mutual_ids = following_ids & followers_ids
          if mutual_ids.any?
            users = users.where(id: mutual_ids)
          else
            # Return empty result if no mutual follows
            users = users.none
          end
        end
        
        # Sort by name
        users = users.order(:name, :username)
        
        # Pagination
        limit = [params[:limit]&.to_i || 50, 200].min
        offset = params[:offset]&.to_i || 0
        total_count = users.count
        users = users.limit(limit).offset(offset)
        
        api_success(
          data: {
            group_chat_id: @group_chat.id,
            group_chat_name: @group_chat.name,
            available_users: users.map do |user|
              {
                id: user.id,
                name: user.name,
                username: user.username,
                avatar_url: user.avatar_url,
                role: user.role,
                bio: user.bio,
                is_following: current_user.following?(user),
                is_followed_by: current_user.followed_by?(user)
              }
            end,
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

      # POST /api/v1/group_chats/:id/add_member
      # Accepts single user_id or bulk member_ids (array). Same role applied to all in bulk.
      def add_member
        role = params[:role] || 'member'
        member_ids = params[:member_ids]

        if member_ids.present?
          # Bulk add
          ids = Array(member_ids).map(&:to_s).reject(&:blank?).uniq
          if ids.empty?
            api_error(message: 'member_ids must be a non-empty array', status: :bad_request)
            return
          end

          added_ids = []
          already_member_ids = []
          not_found_ids = []

          ids.each do |id|
            user = User.find_by(id: id)
            unless user
              not_found_ids << id
              next
            end
            if user == current_user
              already_member_ids << id
              next
            end
            if @group_chat.member?(user)
              already_member_ids << id
              next
            end
            @group_chat.add_member(user, role: role)
            added_ids << id
          end

          api_success(
            data: {
              group_chat: group_chat_response(@group_chat, include_members: true),
              added_member_ids: added_ids,
              already_member_ids: already_member_ids,
              not_found_ids: not_found_ids
            },
            message: bulk_add_message(added_ids, already_member_ids, not_found_ids),
            status: :ok
          )
          return
        end

        # Single add (user_id)
        user = User.find_by(id: params[:user_id])
        unless user
          api_error(message: 'User not found', status: :not_found)
          return
        end
        if @group_chat.member?(user)
          api_error(message: 'User is already a member of this group chat', status: :bad_request)
          return
        end
        @group_chat.add_member(user, role: role)
        api_success(
          data: { group_chat: group_chat_response(@group_chat, include_members: true) },
          message: 'Member added successfully',
          status: :ok
        )
      end

      # DELETE /api/v1/group_chats/:id/remove_member
      def remove_member
        user = User.find_by(id: params[:user_id])
        
        unless user
          api_error(message: 'User not found', status: :not_found)
          return
        end
        
        unless @group_chat.member?(user)
          api_error(message: 'User is not a member of this group chat', status: :bad_request)
          return
        end
        
        if user == @group_chat.created_by
          api_error(message: 'Cannot remove group chat creator', status: :bad_request)
          return
        end
        
        @group_chat.remove_member(user)
        
        api_success(
          data: { group_chat: group_chat_response(@group_chat, include_members: true) },
          message: 'Member removed successfully',
          status: :ok
        )
      end

      # POST /api/v1/group_chats/:id/leave
      def leave
        if @group_chat.owner?(current_user)
          api_error(message: 'Group chat owner cannot leave. Transfer ownership or delete the group.', status: :bad_request)
          return
        end

        @group_chat.remove_member(current_user)
        
        api_success(message: 'Left group chat successfully', status: :ok)
      end

      # POST /api/v1/group_chats/:id/mute
      def mute
        membership = @group_chat.group_chat_memberships.find_by(user: current_user)
        membership&.mute!
        
        api_success(
          data: { group_chat: group_chat_response(@group_chat) },
          message: 'Group chat muted',
          status: :ok
        )
      end

      # POST /api/v1/group_chats/:id/unmute
      def unmute
        membership = @group_chat.group_chat_memberships.find_by(user: current_user)
        membership&.unmute!
        
        api_success(
          data: { group_chat: group_chat_response(@group_chat) },
          message: 'Group chat unmuted',
          status: :ok
        )
      end

      # POST /api/v1/group_chats/:id/pin
      def pin
        membership = @group_chat.group_chat_memberships.find_by(user: current_user)
        membership&.pin!
        
        api_success(
          data: { group_chat: group_chat_response(@group_chat) },
          message: 'Group chat pinned',
          status: :ok
        )
      end

      # POST /api/v1/group_chats/:id/unpin
      def unpin
        membership = @group_chat.group_chat_memberships.find_by(user: current_user)
        membership&.unpin!
        
        api_success(
          data: { group_chat: group_chat_response(@group_chat) },
          message: 'Group chat unpinned',
          status: :ok
        )
      end

      # POST /api/v1/group_chats/:id/star
      def star
        membership = @group_chat.group_chat_memberships.find_by(user: current_user)
        membership&.star!
        
        api_success(
          data: { group_chat: group_chat_response(@group_chat) },
          message: 'Group chat starred',
          status: :ok
        )
      end

      # POST /api/v1/group_chats/:id/unstar
      def unstar
        membership = @group_chat.group_chat_memberships.find_by(user: current_user)
        membership&.unstar!
        
        api_success(
          data: { group_chat: group_chat_response(@group_chat) },
          message: 'Group chat unstarred',
          status: :ok
        )
      end

      # POST /api/v1/group_chats/:id/archive
      def archive
        membership = @group_chat.group_chat_memberships.find_by(user: current_user)
        # Archive is handled at group chat level, but we track user preference
        # For now, we'll use the status field
        @group_chat.update(status: 'archived')
        
        api_success(
          data: { group_chat: group_chat_response(@group_chat) },
          message: 'Group chat archived',
          status: :ok
        )
      end

      # POST /api/v1/group_chats/:id/unarchive
      def unarchive
        @group_chat.update(status: 'active')
        
        api_success(
          data: { group_chat: group_chat_response(@group_chat) },
          message: 'Group chat unarchived',
          status: :ok
        )
      end

      # GET /api/v1/group_chats/:id/invite_qr
      def invite_qr
        qr_data = @group_chat.generate_qr_code
        
        api_success(
          data: {
            qr_code: qr_data,
            invite_code: @group_chat.invite_code,
            invite_url: @group_chat.invite_url
          },
          status: :ok
        )
      end

      # GET /api/v1/group_chats/:id/invite_url
      def invite_url
        api_success(
          data: {
            invite_code: @group_chat.invite_code,
            invite_url: @group_chat.invite_url
          },
          status: :ok
        )
      end

      # POST /api/v1/group_chats/:id/regenerate_invite
      def regenerate_invite
        @group_chat.regenerate_invite_code
        @group_chat.generate_qr_code
        
        api_success(
          data: {
            invite_code: @group_chat.invite_code,
            invite_url: @group_chat.invite_url
          },
          message: 'Invite code regenerated successfully',
          status: :ok
        )
      end

      # POST /api/v1/group_chats/join_by_code
      def join_by_code
        invite_code = params[:invite_code]&.upcase
        group_chat = GroupChat.find_by(invite_code: invite_code, status: 'active')
        
        unless group_chat
          api_error(message: 'Invalid or expired invite code', status: :not_found)
          return
        end

        if group_chat.member?(current_user)
          api_error(message: 'You are already a member of this group chat', status: :bad_request)
          return
        end

        group_chat.add_member(current_user, role: 'member')
        
        api_success(
          data: { group_chat: group_chat_response(group_chat, include_members: true) },
          message: 'Joined group chat successfully',
          status: :ok
        )
      end

      private

      def bulk_add_message(added_ids, already_member_ids, not_found_ids)
        parts = []
        parts << "#{added_ids.size} member(s) added" if added_ids.any?
        parts << "#{already_member_ids.size} already in group" if already_member_ids.any?
        parts << "#{not_found_ids.size} user(s) not found" if not_found_ids.any?
        parts.presence&.join('; ') || 'No members added'
      end

      def set_group_chat
        @group_chat = GroupChat.find_by(id: params[:id])
        unless @group_chat
          api_error(message: 'Group chat not found', status: :not_found)
        end
      end

      def check_group_chat_membership
        unless @group_chat&.member?(current_user)
          api_error(message: 'You are not a member of this group chat', status: :forbidden)
        end
      end

      def check_group_chat_admin
        unless @group_chat&.can_manage?(current_user) || current_user.role_admin?
          api_error(message: 'Only group chat admins can perform this action', status: :forbidden)
        end
      end

      def check_group_chat_owner
        unless @group_chat&.owner?(current_user) || current_user.role_admin?
          api_error(message: 'Only group chat owner can delete the group', status: :forbidden)
        end
      end

      def group_chat_params
        params.require(:group_chat).permit(:name, :description)
      end

      def group_chat_response(group_chat, include_members: false)
        membership = group_chat.group_chat_memberships.find_by(user: current_user)
        
        response = {
          id: group_chat.id,
          name: group_chat.name,
          description: group_chat.description,
          created_by: {
            id: group_chat.created_by.id,
            name: group_chat.created_by.name,
            username: group_chat.created_by.username
          },
          status: group_chat.status,
          is_city_based: group_chat.is_city_based || false,
          city: group_chat.city,
          country: group_chat.country,
          member_count: group_chat.members.count,
          is_member: group_chat.member?(current_user),
          is_owner: group_chat.owner?(current_user),
          is_admin: group_chat.admin?(current_user),
          is_muted: membership&.is_muted || false,
          is_pinned: membership&.is_pinned || false,
          is_starred: membership&.is_starred || false,
          unread_count: membership&.unread_count || 0,
          last_message_at: group_chat.last_message_at&.iso8601,
          created_at: group_chat.created_at.iso8601,
          updated_at: group_chat.updated_at.iso8601
        }
        
        if include_members
          response[:members] = group_chat.members.map do |member|
            membership = group_chat.group_chat_memberships.find_by(user: member)
            {
              id: member.id,
              name: member.name,
              username: member.username,
              role: membership.role,
              joined_at: membership.joined_at.iso8601
            }
          end
        end
        
        response
      end
    end
  end
end

