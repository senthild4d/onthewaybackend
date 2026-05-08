module AuthHelper
  def auth_headers(user)
    token = JsonWebToken.encode(user_id: user.id)
    { 'Authorization' => "Bearer #{token}" }
  end

  def authenticated_user
    @authenticated_user ||= create(:user, :active)
  end

  def auth_token_for(user)
    JsonWebToken.encode(user_id: user.id)
  end
end

