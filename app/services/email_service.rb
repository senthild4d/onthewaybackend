# Email Service for sending OTP codes
class EmailService
  # Send OTP to email address
  def self.send_otp(email, code)
    if sendgrid_configured?
      send_via_sendgrid(email, code)
      return true
    end

    # Fallback: log OTP in non-configured environments
    Rails.logger.info "=" * 50
    Rails.logger.info "OTP for #{email}: #{code}"
    Rails.logger.info "=" * 50
    puts "\n#{'=' * 50}"
    puts "📧 OTP for #{email}: #{code}"
    puts "#{'=' * 50}\n"
    true
  rescue => e
    Rails.logger.error "Failed to send email: #{e.message}"
    false
  end

  private

  def self.send_via_sendgrid(email, code)
    require 'sendgrid-ruby'

    from_email = ENV['SENDGRID_FROM_EMAIL']
    from_name = ENV['SENDGRID_FROM_NAME'] || 'Vibes'
    subject = 'Your Vibes Verification Code'
    content = "Your Vibes verification code is: #{code}. Valid for 5 minutes."

    mail = SendGrid::Mail.new
    mail.from = SendGrid::Email.new(email: from_email, name: from_name)
    mail.subject = subject
    personalization = SendGrid::Personalization.new
    personalization.add_to(SendGrid::Email.new(email: email))
    mail.add_personalization(personalization)
    mail.add_content(SendGrid::Content.new(type: 'text/plain', value: content))

    sg = SendGrid::API.new(api_key: ENV['SENDGRID_API_KEY'])
    response = sg.client.mail._('send').post(request_body: mail.to_json)

    unless response.status_code.to_i.between?(200, 299)
      raise "SendGrid error: status=#{response.status_code} body=#{response.body}"
    end
  end

  def self.sendgrid_configured?
    ENV['SENDGRID_API_KEY'].present? && ENV['SENDGRID_FROM_EMAIL'].present?
  end
end

