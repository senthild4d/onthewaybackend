class JsonWebToken
  SECRET_KEY = Rails.application.credentials.secret_key_base || Rails.application.secret_key_base

  # Default token expiration (24 hours) - for short-lived tokens
  DEFAULT_EXPIRATION = 24.hours

  # Long-lived token expiration (90 days) - for persistent login like Instagram
  PERSISTENT_TOKEN_EXPIRATION = 90.days

  def self.encode(payload, exp = DEFAULT_EXPIRATION.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET_KEY, 'HS256')
  end

  # Generate a long-lived token for persistent login (Instagram-style)
  def self.encode_persistent(payload)
    encode(payload, PERSISTENT_TOKEN_EXPIRATION.from_now)
  end

  def self.decode(token)
    decoded = JWT.decode(token, SECRET_KEY, true, { algorithm: 'HS256' })[0]
    HashWithIndifferentAccess.new(decoded)
  rescue JWT::DecodeError => e
    nil
  end
end

