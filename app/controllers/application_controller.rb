class ApplicationController < ActionController::API
  include ApiResponse
  
  before_action :authenticate_request
  attr_reader :current_user

  # Full URL for default avatar when user has no profile picture
  def default_avatar_url
    "#{base_url_with_prefix}#{'/images/default-avatar.png'}"
  end

  # Generate full URL for ActiveStorage attachments with correct subpath.
  # Accepts ActiveStorage::Attached::One, ActiveStorage::Attachment, or ActiveStorage::Blob.
  def attachment_url(attachment)
    return nil if attachment.nil?
    if attachment.respond_to?(:attached?)
      return nil unless attachment.attached?
    end
    path = Rails.application.routes.url_helpers.rails_blob_path(attachment, only_path: true)
    base = request&.base_url || ENV['API_BASE_URL'] || 'https://vibesapp.digital4design.com'
    "#{base}#{path}"
  end

  def base_url_with_prefix
    base = request&.base_url || ENV['API_BASE_URL'] || 'https://vibesapp.digital4design.com'
    prefix = Rails.application.config.relative_url_root.to_s
    prefix = '' if prefix == '/'
    "#{base}#{prefix}"
  end

  # Returns [page, per_page, offset] for the current request.
  def pagination_params(default_per_page: 20, max_per_page: 100)
    page = params[:page].to_i
    page = 1 if page < 1

    requested = params[:per_page].presence || params[:limit].presence
    per_page = requested.to_i
    per_page = default_per_page if per_page <= 0
    per_page = max_per_page if per_page > max_per_page

    offset = (page - 1) * per_page
    [page, per_page, offset]
  end

  def require_admin!
    unless current_user&.admin?
      api_error(message: 'Admin access required', status: :forbidden)
      return
    end
  end

  private

  def authenticate_request
    @current_user = authorize_request
  end

  def authorize_request
    header = request.headers['Authorization']
    token = nil

    if header.present?
      token = header.split(' ').last
    else
      token_param = params[:auth_token].presence || params[:token].presence || params[:authorization].presence
      token = token_param&.to_s
      token = token.split(' ').last if token&.include?(' ')
    end

    return nil unless token.present?
    puts "token: #{token}"
    decoded = JsonWebToken.decode(token)
    return nil unless decoded

    @current_user = User.find_by(id: decoded[:user_id])
  end

  def require_authentication!
    unless current_user
      api_error(message: 'Unauthorized', status: :unauthorized)
      return
    end
  end

  def require_role!(required_role)
    unless current_user&.role == required_role.to_s
      api_error(message: 'Forbidden: Insufficient permissions', status: :forbidden)
      return
    end
  end
end
