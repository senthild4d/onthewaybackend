module Api
  module V1
    class AllergensController < ApplicationController
      before_action :require_authentication!, except: [:index]
      before_action :require_admin!, only: [:create, :destroy]

      # GET /api/v1/allergens
      def index
        api_success(
          data: {
            allergens: Allergen.order(:label).map { |allergen| allergen_response(allergen) }
          },
          status: :ok
        )
      end

      # POST /api/v1/allergens
      def create
        allergen = Allergen.new(allergen_params)

        if allergen.save
          api_success(
            data: { allergen: allergen_response(allergen) },
            message: 'Allergen created successfully',
            status: :created
          )
        else
          api_validation_error(errors: allergen.errors.full_messages)
        end
      end

      # DELETE /api/v1/allergens/:id
      def destroy
        allergen = Allergen.find_by(id: params[:id])
        unless allergen
          api_error(message: 'Allergen not found', status: :not_found)
          return
        end

        allergen.destroy
        api_success(message: 'Allergen deleted successfully', status: :ok)
      end

      private

      def require_admin!
        require_role!('admin')
      end

      def allergen_params
        params.require(:allergen).permit(:code, :label, :description)
      end

      def allergen_response(allergen)
        {
          id: allergen.id,
          code: allergen.code,
          label: allergen.label,
          description: allergen.description
        }
      end
    end
  end
end
