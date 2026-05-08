module Api
  module V1
    class VenueMenusController < ApplicationController
      before_action :require_authentication!, except: [:index, :show, :show_category, :show_item]
      before_action :set_venue
      before_action :check_venue_ownership, only: [:create, :update, :destroy, :create_category, :update_category, :delete_category, :reorder_categories, :create_item, :update_item, :delete_item, :upload_menu_image, :remove_menu_image, :upload_category_image, :remove_category_image, :upload_item_image, :remove_item_image]
      before_action :set_menu, only: [:show, :update, :destroy, :create_category, :update_category, :delete_category, :reorder_categories, :show_category, :show_item, :create_item, :update_item, :delete_item, :upload_menu_image, :remove_menu_image, :upload_category_image, :remove_category_image, :upload_item_image, :remove_item_image], if: -> { params[:menu_id].present? || %w[show update destroy].include?(action_name) }
      
      # GET /api/v1/venues/:venue_id/menus
      def index
        menus = @venue.venue_menus.active.includes(venue_menu_categories: :venue_menu_items)
        
        # Filter by type if provided
        menus = menus.by_type(params[:type]) if params[:type].present?

        query = params[:q].presence || params[:query].presence || params[:search].presence
        
        api_success(
          data: {
            venue: {
              id: @venue.id,
              name: @venue.name
            },
            menus: menus.map { |menu| query ? filtered_menu_response(menu, query) : menu_response(menu) }.compact
          },
          status: :ok
        )
      end

      # GET /api/v1/venues/:venue_id/menus/:id
      def show
        api_success(
          data: { menu: menu_response(@menu) },
          status: :ok
        )
      end

      # GET /api/v1/venues/:venue_id/menus/:menu_id/categories/:id
      def show_category
        category = @menu.venue_menu_categories.find(params[:id])
        api_success(data: { category: category_response(category) }, status: :ok)
      end

      # GET /api/v1/venues/:venue_id/menus/:menu_id/items/:id
      def show_item
        item = @menu.venue_menu_items.find(params[:id])
        api_success(data: { item: item_response(item) }, status: :ok)
      end
      
      # POST /api/v1/venues/:venue_id/menus
      def create
        menu = @venue.venue_menus.build(menu_params)
        
        if menu.save
          attach_image_if_present(menu)
          api_success(
            data: { menu: menu_response(menu) },
            message: 'Venue menu created successfully',
            status: :created
          )
        else
          api_validation_error(errors: menu.errors.full_messages)
        end
      end
      
      # PATCH /api/v1/venues/:venue_id/menus/:id
      def update
        if @menu.update(menu_params)
          attach_image_if_present(@menu)
          api_success(
            data: { menu: menu_response(@menu) },
            message: 'Venue menu updated successfully',
            status: :ok
          )
        else
          api_validation_error(errors: @menu.errors.full_messages)
        end
      end
      
      # DELETE /api/v1/venues/:venue_id/menus/:id
      def destroy
        if @menu.destroy
          api_success(message: 'Venue menu deleted successfully', status: :ok)
        else
          api_validation_error(errors: @menu.errors.full_messages)
        end
      end
      
      # POST /api/v1/venues/:venue_id/menus/:menu_id/categories
      def create_category
        category = @menu.venue_menu_categories.build(category_params)
        
        if category.save
          attach_image_if_present(category)
          api_success(
            data: { category: category_response(category) },
            message: 'Menu category created successfully',
            status: :created
          )
        else
          api_validation_error(errors: category.errors.full_messages)
        end
      end
      
      # PATCH /api/v1/venues/:venue_id/menus/:menu_id/categories/:id
      def update_category
        category = @menu.venue_menu_categories.find(params[:id])
        
        if category.update(category_params)
          attach_image_if_present(category)
          api_success(
            data: { category: category_response(category) },
            message: 'Menu category updated successfully',
            status: :ok
          )
        else
          api_validation_error(errors: category.errors.full_messages)
        end
      end

      # POST /api/v1/venues/:venue_id/menus/:menu_id/categories/reorder
      def reorder_categories
        category_ids = params[:category_ids] || []

        unless category_ids.is_a?(Array) && category_ids.any?
          api_error(message: 'category_ids is required', status: :bad_request)
          return
        end

        categories = @menu.venue_menu_categories.where(id: category_ids)
        if categories.size != category_ids.size
          api_error(message: 'One or more categories not found', status: :not_found)
          return
        end

        VenueMenuCategory.transaction do
          category_ids.each_with_index do |category_id, index|
            @menu.venue_menu_categories.where(id: category_id)
                 .update_all(display_order: index + 1, updated_at: Time.current)
          end
        end

        api_success(
          data: { categories: @menu.venue_menu_categories.ordered.map { |cat| category_response(cat) } },
          message: 'Category order updated successfully',
          status: :ok
        )
      end
      
      # DELETE /api/v1/venues/:venue_id/menus/:menu_id/categories/:id
      def delete_category
        category = @menu.venue_menu_categories.find(params[:id])
        category.destroy
        
        api_success(message: 'Menu category deleted successfully', status: :ok)
      end
      
      # POST /api/v1/venues/:venue_id/menus/:menu_id/items
      def create_item
        category_id = params[:menu_category_id] || params.dig(:item, :menu_category_id) || params.dig('item', 'menu_category_id')
        category = @menu.venue_menu_categories.find(category_id)
        item = category.venue_menu_items.build(item_params)
        
        if item.save
          attach_image_if_present(item)
          api_success(
            data: { item: item_response(item) },
            message: 'Menu item created successfully',
            status: :created
          )
        else
          api_validation_error(errors: item.errors.full_messages)
        end
      end
      
      # PATCH /api/v1/venues/:venue_id/menus/:menu_id/items/:id
      def update_item
        item = @menu.venue_menu_items.find(params[:id])
        
        if item.update(item_params)
          attach_image_if_present(item)
          api_success(
            data: { item: item_response(item) },
            message: 'Menu item updated successfully',
            status: :ok
          )
        else
          api_validation_error(errors: item.errors.full_messages)
        end
      end
      
      # DELETE /api/v1/venues/:venue_id/menus/:menu_id/items/:id
      def delete_item
        item = @menu.venue_menu_items.find(params[:id])
        
        # Check if item can be deleted (no orders for venue menu items currently, but good to have check)
        item.destroy
        api_success(message: 'Menu item deleted successfully', status: :ok)
      end

      # POST /api/v1/venues/:venue_id/menus/:menu_id/image
      def upload_menu_image
        error = validate_image!(params[:image])
        return if error && api_error(message: error, status: :bad_request)

        @menu.image.attach(params[:image])
        api_success(data: { menu: menu_response(@menu) }, message: 'Menu image uploaded', status: :ok)
      end

      # DELETE /api/v1/venues/:venue_id/menus/:menu_id/image
      def remove_menu_image
        unless @menu.image.attached?
          api_error(message: 'Menu image not found', status: :not_found)
          return
        end

        @menu.image.purge
        api_success(message: 'Menu image removed', status: :ok)
      end

      # POST /api/v1/venues/:venue_id/menus/:menu_id/categories/:id/image
      def upload_category_image
        category = @menu.venue_menu_categories.find(params[:id])
        error = validate_image!(params[:image])
        return if error && api_error(message: error, status: :bad_request)

        category.image.attach(params[:image])
        api_success(data: { category: category_response(category) }, message: 'Category image uploaded', status: :ok)
      end

      # DELETE /api/v1/venues/:venue_id/menus/:menu_id/categories/:id/image
      def remove_category_image
        category = @menu.venue_menu_categories.find(params[:id])
        unless category.image.attached?
          api_error(message: 'Category image not found', status: :not_found)
          return
        end

        category.image.purge
        api_success(message: 'Category image removed', status: :ok)
      end

      # POST /api/v1/venues/:venue_id/menus/:menu_id/items/:id/image
      def upload_item_image
        item = @menu.venue_menu_items.find(params[:id])
        error = validate_image!(params[:image])
        return if error && api_error(message: error, status: :bad_request)

        item.image.attach(params[:image])
        api_success(data: { item: item_response(item) }, message: 'Item image uploaded', status: :ok)
      end

      # DELETE /api/v1/venues/:venue_id/menus/:menu_id/items/:id/image
      def remove_item_image
        item = @menu.venue_menu_items.find(params[:id])
        unless item.image.attached?
          api_error(message: 'Item image not found', status: :not_found)
          return
        end

        item.image.purge
        api_success(message: 'Item image removed', status: :ok)
      end
      
      private
      
      def set_venue
        @venue = Venue.find_by(id: params[:venue_id])
        unless @venue
          api_error(message: 'Venue not found', status: :not_found)
          return
        end
      end
      
      def set_menu
        menu_id = params[:menu_id].presence
        if menu_id.blank? && %w[show update destroy].include?(action_name)
          menu_id = params[:id]
        end
        @menu = @venue.venue_menus.find_by(id: menu_id)
        unless @menu
          api_error(message: 'Menu not found', status: :not_found)
          return
        end
      end
      
      def check_venue_ownership
        unless @venue.owner_id == current_user.id || current_user.role_admin?
          api_error(message: 'Only venue owners can manage menus', status: :forbidden)
          return
        end
      end
      
      def menu_params
        params.require(:menu).permit(
          :name,
          :menu_type,
          :description,
          :is_active,
          :available_from,
          :available_until
        )
      end
      
      def category_params
        params.require(:category).permit(
          :name,
          :category_type,
          :description,
          :display_order,
          :is_active
        )
      end
      
      def item_params
        params.require(:item).permit(
          :name,
          :description,
          :price,
          :currency,
          :item_type,
          :image_url,
          :is_available,
          :is_vegetarian,
          :is_vegan,
          :is_gluten_free,
          :contains_alcohol,
          :ingredients,
          :preparation_time_minutes,
          :display_order,
          allergens: []
        )
      end
      
      def menu_response(menu)
        {
          id: menu.id,
          venue_id: menu.venue_id,
          name: menu.name,
          menu_type: menu.menu_type,
          description: menu.description,
          is_active: menu.is_active,
          image_url: attachment_url(menu.image),
          available_from: menu.available_from&.iso8601,
          available_until: menu.available_until&.iso8601,
          available_now: menu.available_now?,
          categories: menu.venue_menu_categories.active.ordered.map { |cat| category_response(cat) },
          created_at: menu.created_at.iso8601,
          updated_at: menu.updated_at.iso8601
        }
      end
      
      def category_response(category)
        {
          id: category.id,
          venue_menu_id: category.venue_menu_id,
          name: category.name,
          category_type: category.category_type,
          description: category.description,
          display_order: category.display_order,
          is_active: category.is_active,
          image_url: attachment_url(category.image),
          items: category.venue_menu_items.available.ordered.map { |item| item_response(item) },
          created_at: category.created_at.iso8601,
          updated_at: category.updated_at.iso8601
        }
      end
      
      def item_response(item)
        {
          id: item.id,
          venue_menu_category_id: item.venue_menu_category_id,
          name: item.name,
          description: item.description,
          price: item.price.to_f,
          currency: item.currency,
          item_type: item.item_type,
          image_url: attachment_url(item.image) || item.image_url,
          is_available: item.is_available,
          dietary_info: {
            is_vegetarian: item.is_vegetarian,
            is_vegan: item.is_vegan,
            is_gluten_free: item.is_gluten_free,
            contains_alcohol: item.contains_alcohol
          },
          allergens: item.allergens_list,
          ingredients: item.ingredients,
          preparation_time_minutes: item.preparation_time_minutes,
          display_order: item.display_order,
          created_at: item.created_at.iso8601,
          updated_at: item.updated_at.iso8601
        }
      end

      def attachment_url(attachment)
        return nil unless attachment&.attached?

        Rails.application.routes.url_helpers.rails_blob_url(attachment, host: request.base_url)
      end

      def validate_image!(file)
        return 'Image file is required' unless file
        return 'Invalid file type. Only JPEG, PNG, GIF, and WebP are allowed' unless file.content_type.in?(%w[image/jpeg image/jpg image/png image/gif image/webp])
        return 'File is too large. Maximum size is 10MB' if file.size > 10.megabytes

        nil
      end

      def attach_image_if_present(record)
        return unless params[:image].present?

        error = validate_image!(params[:image])
        return if error && api_error(message: error, status: :bad_request)

        record.image.attach(params[:image])
      end

      def filtered_menu_response(menu, query)
        needle = query.to_s.strip.downcase
        return menu_response(menu) if needle.blank?

        menu_matches = [menu.name, menu.description].compact.any? { |text| text.to_s.downcase.include?(needle) }
        matching_categories = menu.venue_menu_categories.active.ordered.map do |category|
          category_matches = [category.name, category.description].compact.any? { |text| text.to_s.downcase.include?(needle) }
          matching_items = category.venue_menu_items.available.ordered.select do |item|
            [item.name, item.description, item.ingredients].compact.any? { |text| text.to_s.downcase.include?(needle) }
          end
          next if matching_items.empty? && !category_matches

          category_response(category).merge(items: matching_items.map { |item| item_response(item) })
        end.compact

        return nil if matching_categories.empty? && !menu_matches

        menu_response(menu).merge(categories: matching_categories)
      end

    end
  end
end

