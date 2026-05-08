# SMS Service for sending OTP codes
class SmsService
  # Send OTP to phone number
  def self.send_otp(phone, code)
    if twilio_configured?
      send_via_twilio(phone, code)
      return true
    end

    # Fallback: log OTP in non-configured environments
    Rails.logger.info "=" * 50
    Rails.logger.info "OTP for #{phone}: #{code}"
    Rails.logger.info "=" * 50
    puts "\n#{'=' * 50}"
    puts "📱 OTP for #{phone}: #{code}"
    puts "#{'=' * 50}\n"
    true
  rescue => e
    Rails.logger.error "Failed to send SMS: #{e.message}"
    false
  end

  private

  def self.send_via_twilio(phone, code)
    require 'twilio-ruby'

    body = "Your Vibes verification code is: #{code}. Valid for 5 minutes."
    client = Twilio::REST::Client.new(ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN'])

    if ENV['TWILIO_MESSAGING_SERVICE_SID'].present?
      client.messages.create(
        messaging_service_sid: ENV['TWILIO_MESSAGING_SERVICE_SID'],
        to: phone,
        body: body
      )
    else
      client.messages.create(
        from: ENV['TWILIO_PHONE_NUMBER'],
        to: phone,
        body: body
      )
    end
  end

  def self.twilio_configured?
    ENV['TWILIO_ACCOUNT_SID'].present? &&
      ENV['TWILIO_AUTH_TOKEN'].present? &&
      (ENV['TWILIO_MESSAGING_SERVICE_SID'].present? || ENV['TWILIO_PHONE_NUMBER'].present?)
  end
end

