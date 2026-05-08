module Api
  module V1
    class ArtistCategoriesController < ApplicationController
      before_action :require_authentication!
      before_action :set_manager

      def index
        # Get all categories with their groups
        all_categories = Category.includes(:categories_group)
                                 .joins(:categories_group)
                                 .order('categories_groups.display_order, categories.display_order')
        
        # Get user's subscribed category IDs for efficient lookup
        subscribed_category_ids = current_user.artist_categories.pluck(:category_id).to_set
        
        # Group categories by their category group
        categories_by_group = all_categories.group_by(&:categories_group)
        
        # Build response with all categories and subscribed flag
        categories_groups_data = categories_by_group.map do |group, categories|
          {
            id: group.id,
            name: group.name,
            slug: group.slug,
            description: group.description,
            display_order: group.display_order,
            categories: categories.map do |category|
              {
                id: category.id,
                categories_group_id: category.categories_group_id,
                name: category.name,
                slug: category.slug,
                icon_key: category.icon_key,
                display_order: category.display_order,
                subscribed: subscribed_category_ids.include?(category.id)
              }
            end
          }
        end
        
        # Also include flat list of all categories for backward compatibility
        all_categories_flat = all_categories.map do |category|
          {
            id: category.id,
            categories_group_id: category.categories_group_id,
            name: category.name,
            slug: category.slug,
            icon_key: category.icon_key,
            display_order: category.display_order,
            subscribed: subscribed_category_ids.include?(category.id)
          }
        end
        
        api_success(data: {
          categories_groups: categories_groups_data,
          categories: all_categories_flat,
          subscribed_category_ids: subscribed_category_ids.to_a
        })
      end

      def replace
        categories = @manager.set_categories!(category_ids: category_ids_param, source: source_param)
        api_success(data: serialized_categories(categories))
      rescue ArtistCategoryManager::ValidationError => e
        api_validation_error(errors: e.errors)
      rescue ActiveRecord::RecordInvalid => e
        api_validation_error(errors: [e.message])
      end

      def add
        categories = @manager.add_categories!(category_ids: category_ids_param, source: source_param || 'profile_edit')
        api_success(data: serialized_categories(categories))
      rescue ArtistCategoryManager::ValidationError => e
        api_validation_error(errors: e.errors)
      rescue ActiveRecord::RecordInvalid => e
        api_validation_error(errors: [e.message])
      end

      def remove
        categories = @manager.remove_categories!(category_ids: category_ids_param)
        api_success(data: serialized_categories(categories))
      rescue ArtistCategoryManager::ValidationError => e
        api_validation_error(errors: e.errors)
      end

      private

      def set_manager
        @manager = ArtistCategoryManager.new(current_user)
      end

      def category_ids_param
        values = params[:category_ids] || params.dig(:artist_category, :category_ids)
        Array(values).map(&:to_s).reject(&:blank?)
      end

      def source_param
        params[:source] || params.dig(:artist_category, :source)
      end

      def serialized_categories(categories)
        {
          category_ids: categories.map(&:id),
          categories: categories.map do |category|
            {
              id: category.id,
              categories_group_id: category.categories_group_id,
              name: category.name,
              slug: category.slug,
              icon_key: category.icon_key,
              display_order: category.display_order
            }
          end
        }
      end
    end
  end
end

