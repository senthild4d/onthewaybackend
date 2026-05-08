class ArtistCategoryManager
  class ValidationError < StandardError
    attr_reader :errors

    def initialize(errors)
      super('Artist category validation failed')
      @errors = errors
    end
  end

  def initialize(user)
    @user = user
  end

  def set_categories!(category_ids:, source: 'onboarding')
    validated_ids = validate_category_ids(category_ids)

    ActiveRecord::Base.transaction do
      current_ids = user.artist_categories.pluck(:category_id)
      to_remove = current_ids - validated_ids
      to_add = validated_ids - current_ids

      ArtistCategory.where(user_id: user.id, category_id: to_remove).delete_all if to_remove.any?

      to_add.each do |category_id|
        ArtistCategory.create!(user_id: user.id, category_id: category_id, source: source)
      end
    end

    load_categories
  end

  def add_categories!(category_ids:, source: 'profile_edit')
    validated_ids = validate_category_ids(category_ids)

    validated_ids.each do |category_id|
      ArtistCategory.find_or_create_by!(user_id: user.id, category_id: category_id) do |record|
        record.source = source
      end
    end

    load_categories
  end

  def remove_categories!(category_ids:)
    ArtistCategory.where(user_id: user.id, category_id: category_ids).delete_all
    load_categories
  end

  def categories
    load_categories
  end

  private

  attr_reader :user

  def validate_category_ids(category_ids)
    ids = Array(category_ids).map(&:to_s).reject(&:blank?)
    invalid = ids.reject { |id| id.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i) }
    raise ValidationError.new(["Invalid category ids: #{invalid.join(', ')}"]) if invalid.any?

    return [] if ids.empty?

    found_ids = Category.where(id: ids).pluck(:id).map(&:to_s)
    missing = ids - found_ids

    raise ValidationError.new(["Invalid category ids: #{missing.join(', ')}"]) if missing.any?

    found_ids
  end

  def load_categories
    user.categories.distinct.order(:display_order)
  end
end

