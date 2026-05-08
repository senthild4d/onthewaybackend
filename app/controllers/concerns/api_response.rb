module ApiResponse
  extend ActiveSupport::Concern

  # Success response
  # Usage: api_success(data: { user: @user }, message: 'User created successfully', status: :created)
  def api_success(data: [], message: 'Success', status: :ok)
    status = normalize_api_status(status)
    render json: {
      status: Rack::Utils.status_code(status),
      message: message,
      data: data
    }, status: status
  end

  # Error response
  # Usage: api_error(message: 'User not found', status: :not_found)
  def api_error(message: 'Error', data: nil, status: :bad_request)
    status = normalize_api_status(status)
    render json: {
      status: Rack::Utils.status_code(status),
      message: message,
      data: data
    }, status: status
  end

  # Validation error response
  # Usage: api_validation_error(errors: @user.errors.full_messages)
  # OR: api_validation_error(message: 'Custom error message')
  def api_validation_error(errors: [], message: nil)
    # If errors array provided, join them into message
    final_message = if message.present?
      message
    elsif errors.present?
      errors.is_a?(Array) ? errors.first : errors.to_s
    else
      'Validation failed'
    end
    
    render json: {
      status: 400,
      message: final_message,
      data: nil
    }, status: :bad_request
  end

  private

  # Rack 3 deprecates :unprocessable_entity; :unprocessable_content is the canonical symbol for HTTP 422.
  def normalize_api_status(status)
    return status if status.nil?
    status == :unprocessable_entity ? :unprocessable_content : status
  end
end











