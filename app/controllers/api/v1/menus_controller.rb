module Api
  module V1
    class MenusController < ApplicationController
      before_action :require_authentication!, except: [:index, :show_menu, :show_category, :show_item]
      before_action :set_event
      before_action :check_event_ownership, only: [:create_menu, :update_menu, :delete_menu, :create_category, :update_category, :delete_category, :reorder_categories, :create_item, :update_item, :delete_item, :upload_menu_image, :remove_menu_image, :upload_category_image, :remove_category_image, :upload_item_image, :remove_item_image]
      
      # GET /api/v1/events/:event_id/menus
      def index
        menus = @event.event_menus.active.includes(menu_categories: :menu_items)
        
        # Filter by type if provided
        menus = menus.by_type(params[:type]) if params[:type].present?
        
        api_success(
          data: {
            event: {
              id: @event.id,
              title: @event.title
            },
            menus: menus.map { |menu| menu_response(menu) }
          }
        )
      end

      # POST /api/v1/events/:event_id/menus
      def create_menu
        menu = @event.event_menus.build(menu_params)
        
        if menu.save
          attach_image_if_present(menu)
          api_success(
            data: { menu: menu_response(menu) },
            message: 'Event menu created successfully',
            status: :created
          )
        else
          api_validation_error(errors: menu.errors.full_messages)
        end
      end

      # GET /api/v1/events/:event_id/menus/:menu_id
      def show_menu
        menu = @event.event_menus.includes(menu_categories: :menu_items).find(params[:menu_id])
        api_success(data: { menu: menu_response(menu) }, status: :ok)
      end
      
      # POST /api/v1/events/:event_id/menus/:menu_id/categories
      def create_category
        menu = @event.event_menus.find(params[:menu_id])
        category = menu.menu_categories.build(category_params)
        
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

      # GET /api/v1/events/:event_id/menus/:menu_id/categories/:id
      def show_category
        menu = @event.event_menus.find(params[:menu_id])
        category = menu.menu_categories.find(params[:id])
        api_success(data: { category: category_response(category) }, status: :ok)
      end
      
      # PATCH /api/v1/events/:event_id/menus/:menu_id/categories/:id
      def update_category
        menu = @event.event_menus.find(params[:menu_id])
        category = menu.menu_categories.find(params[:id])
        
        if category.update(category_params)
          attach_image_if_present(category)
          api_success(
            data: { category: category_response(category) },
            message: 'Menu category updated successfully'
          )
        else
          api_validation_error(errors: category.errors.full_messages)
        end
      end

      # POST /api/v1/events/:event_id/menus/:menu_id/categories/reorder
      def reorder_categories
        menu = @event.event_menus.find(params[:menu_id])
        category_ids = params[:category_ids] || []

        unless category_ids.is_a?(Array) && category_ids.any?
          api_error(message: 'category_ids is required', status: :bad_request)
          return
        end

        categories = menu.menu_categories.where(id: category_ids)
        if categories.size != category_ids.size
          api_error(message: 'One or more categories not found', status: :not_found)
          return
        end

        MenuCategory.transaction do
          category_ids.each_with_index do |category_id, index|
            menu.menu_categories.where(id: category_id)
                .update_all(display_order: index + 1, updated_at: Time.current)
          end
        end

        api_success(
          data: { categories: menu.menu_categories.ordered.map { |cat| category_response(cat) } },
          message: 'Category order updated successfully',
          status: :ok
        )
      end
      
      # DELETE /api/v1/events/:event_id/menus/:menu_id/categories/:id
      def delete_category
        menu = @event.event_menus.find(params[:menu_id])
        category = menu.menu_categories.find(params[:id])
        category.destroy
        
        api_success(message: 'Menu category deleted successfully')
      end
      
      # POST /api/v1/events/:event_id/menus/:menu_id/items
      def create_item
        menu = @event.event_menus.find(params[:menu_id])
        category = menu.menu_categories.find(params[:menu_category_id])
        item = category.menu_items.build(item_params)
        
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

      # GET /api/v1/events/:event_id/menus/:menu_id/items/:id
      def show_item
        menu = @event.event_menus.find(params[:menu_id])
        item = menu.menu_items.find(params[:id])
        api_success(data: { item: item_response(item) }, status: :ok)
      end
      
      # PATCH /api/v1/events/:event_id/menus/:menu_id/items/:id
      def update_item
        menu = @event.event_menus.find(params[:menu_id])
        item = menu.menu_items.find(params[:id])
        
        if item.update(item_params)
          attach_image_if_present(item)
          api_success(
            data: { item: item_response(item) },
            message: 'Menu item updated successfully'
          )
        else
          api_validation_error(errors: item.errors.full_messages)
        end
      end
      
      # DELETE /api/v1/events/:event_id/menus/:menu_id/items/:id
      def delete_item
        menu = @event.event_menus.find(params[:menu_id])
        item = menu.menu_items.find(params[:id])
        
        if item.food_bar_order_items.any?
          api_error(
            message: 'Cannot delete menu item that has been ordered',
            status: :unprocessable_entity
          )
        else
          item.destroy
          api_success(message: 'Menu item deleted successfully')
        end
      end

      # POST /api/v1/events/:event_id/menus/:menu_id/image
      def upload_menu_image
        menu = @event.event_menus.find(params[:menu_id])
        error = validate_image!(params[:image])
        return if error && api_error(message: error, status: :bad_request)

        menu.image.attach(params[:image])
        api_success(data: { menu: menu_response(menu) }, message: 'Menu image uploaded', status: :ok)
      end

      # DELETE /api/v1/events/:event_id/menus/:menu_id/image
      def remove_menu_image
        menu = @event.event_menus.find(params[:menu_id])
        unless menu.image.attached?
          api_error(message: 'Menu image not found', status: :not_found)
          return
        end

        menu.image.purge
        api_success(message: 'Menu image removed', status: :ok)
      end

      # POST /api/v1/events/:event_id/menus/:menu_id/categories/:id/image
      def upload_category_image
        menu = @event.event_menus.find(params[:menu_id])
        category = menu.menu_categories.find(params[:id])
        error = validate_image!(params[:image])
        return if error && api_error(message: error, status: :bad_request)

        category.image.attach(params[:image])
        api_success(data: { category: category_response(category) }, message: 'Category image uploaded', status: :ok)
      end

      # DELETE /api/v1/events/:event_id/menus/:menu_id/categories/:id/image
      def remove_category_image
        menu = @event.event_menus.find(params[:menu_id])
        category = menu.menu_categories.find(params[:id])
        unless category.image.attached?
          api_error(message: 'Category image not found', status: :not_found)
          return
        end

        category.image.purge
        api_success(message: 'Category image removed', status: :ok)
      end

      # POST /api/v1/events/:event_id/menus/:menu_id/items/:id/image
      def upload_item_image
        menu = @event.event_menus.find(params[:menu_id])
        item = menu.menu_items.find(params[:id])
        error = validate_image!(params[:image])
        return if error && api_error(message: error, status: :bad_request)

        item.image.attach(params[:image])
        api_success(data: { item: item_response(item) }, message: 'Item image uploaded', status: :ok)
      end

      # DELETE /api/v1/events/:event_id/menus/:menu_id/items/:id/image
      def remove_item_image
        menu = @event.event_menus.find(params[:menu_id])
        item = menu.menu_items.find(params[:id])
        unless item.image.attached?
          api_error(message: 'Item image not found', status: :not_found)
          return
        end

        item.image.purge
        api_success(message: 'Item image removed', status: :ok)
      end
      
      private
      
      def set_event
        @event = Event.find_by(id: params[:event_id])
        unless @event
          api_error(message: 'Event not found', status: :not_found)
          return
        end
      end
      
      def check_event_ownership
        unless @event.creator_id == current_user.id || current_user.role_admin?
          api_error(message: 'Only venue owners can manage event menu', status: :forbidden)
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
          name: menu.name,
          menu_type: menu.menu_type,
          description: menu.description,
          is_active: menu.is_active,
          image_url: attachment_url(menu.image),
          available_from: menu.available_from&.iso8601,
          available_until: menu.available_until&.iso8601,
          available_now: menu.available_now?,
          categories: menu.menu_categories.active.ordered.map { |cat| category_response(cat) }
        }
      end
      
      def category_response(category)
        {
          id: category.id,
          name: category.name,
          description: category.description,
          display_order: category.display_order,
          is_active: category.is_active,
          image_url: attachment_url(category.image),
          items: category.menu_items.available.ordered.map { |item| item_response(item) }
        }
      end
      
      def item_response(item)
        {
          id: item.id,
          menu_category_id: item.menu_category_id,
          name: item.name,
          description: item.description,
          price: item.price.to_f,
          currency: item.currency,
          image_url: attachment_url(item.image) || item.image_url,
          is_available: item.is_available,
          dietary_info: {
            is_vegetarian: item.is_vegetarian,
            is_vegan: item.is_vegan,
            is_gluten_free: item.is_gluten_free,
            contains_alcohol: item.contains_alcohol
          },
          allergens: item.allergens_list,
          ingredients: item.respond_to?(:ingredients) ? item.ingredients : nil,
          preparation_time_minutes: item.preparation_time_minutes,
          display_order: item.display_order
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

    end
  end
end

