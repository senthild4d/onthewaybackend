module Api
  module V1
    class CategoriesGroupsController < ApplicationController
      before_action :require_authentication!

      def index
        groups = CategoriesGroup.includes(:categories).order(:display_order)
        data = groups.map do |group|
          {
            id: group.id,
            name: group.name,
            slug: group.slug,
            description: group.description,
            display_order: group.display_order,
            categories: group.categories.order(:display_order).map do |category|
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

        api_success(data: { categories_groups: data })
      end
    end
  end
end

