class ApplicationController < ActionController::API
  include ApiResponse
  
  before_action :authenticate_request
  attr_reader :current_user

  # Full URL for default avatar when user has no profile picture
  def default_avatar_url
    base = request&.base_url || ENV['API_BASE_URL'] || 'https://vibesapp.digital4design.com/ontheway'
    "#{base}#{DEFAULT_AVATAR_PATH}"
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
