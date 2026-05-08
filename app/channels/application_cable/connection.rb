module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      token = request.params[:token] || extract_token_from_header
      reject_unauthorized_connection unless token

      decoded = JsonWebToken.decode(token)
      reject_unauthorized_connection unless decoded

      user = User.find_by(id: decoded[:user_id])
      reject_unauthorized_connection unless user&.status_active?

      user
    end

    def extract_token_from_header
      header = request.headers['Authorization']
      return nil unless header.present?

      header.split(' ').last
    end
  end
end

