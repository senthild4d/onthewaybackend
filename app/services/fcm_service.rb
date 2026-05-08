# Send push notifications via Firebase Cloud Messaging (FCM) HTTP v1 API.
# Requires: GOOGLE_APPLICATION_CREDENTIALS (path to service account JSON) and FCM_PROJECT_ID (or project_id in JSON).
class FcmService
  class << self
    # Send to a single FCM registration token.
    # @param token [String] FCM device token
    # @param title [String] Notification title
    # @param body [String] Notification body
    # @param data [Hash] Optional key-value data payload (values must be strings for FCM)
    # @return [Hash] { success:, response:, error:, unregistered: } — unregistered: true when token is invalid (app uninstalled / token rotated)
    def send_to_token(token, title:, body:, data: {})
      return { success: false, error: 'FCM not configured', unregistered: false } unless configured?
      return { success: false, error: 'Token is blank', unregistered: false } if token.blank?

      client = build_client
      return { success: false, error: client[:error], unregistered: false } if client[:error]

      message = {
        token: token.to_s.strip,
        notification: {
          title: title.to_s,
          body: body.to_s
        }
      }
      message[:data] = data.transform_values(&:to_s) if data.present?

      response = client[:fcm].send_v1(message)
      success = response.is_a?(Hash) && response[:status_code] == 200
      unregistered = fcm_response_unregistered?(response)
      Rails.logger.info "FCM token UNREGISTERED (invalid), should be cleared" if unregistered
      { success: success, response: response, unregistered: unregistered }
    rescue StandardError => e
      Rails.logger.error "FCM send_to_token error: #{e.message}"
      { success: false, error: e.message, response: nil, unregistered: false }
    end

    # Send notification to all active devices for a user.
    # @param user [User] User to send notification to
    # @param title [String] Notification title
    # @param body [String] Notification body
    # @param data [Hash] Optional key-value data payload
    # @return [Hash] { success_count: Integer, failed_count: Integer, results: Array }
    def send_to_user(user, title:, body:, data: {})
      return { success_count: 0, failed_count: 0, results: [], error: 'FCM not configured' } unless configured?

      devices = user.devices.active.where.not(fcm_token: nil)
      return { success_count: 0, failed_count: 0, results: [], error: 'No devices with FCM tokens found' } if devices.empty?

      results = []
      success_count = 0
      failed_count = 0

      devices.each do |device|
        result = send_to_token(device.fcm_token, title: title, body: body, data: data)
        results << { device_id: device.id, success: result[:success], error: result[:error], unregistered: result[:unregistered] }
        if result[:unregistered]
          device.clear_fcm_token!
          Rails.logger.info "FCM: cleared invalid token for device #{device.id} (user #{user.id})"
        end
        result[:success] ? success_count += 1 : failed_count += 1
      end

      { success_count: success_count, failed_count: failed_count, results: results }
    end

    def configured?
      return false unless credentials_path.present?
      return false unless File.file?(credentials_path)
      return false unless project_id.present?
      true
    end

    def configuration_status
      creds_path = credentials_path
      file_exists = creds_path.present? && File.file?(creds_path)
      file_readable = file_exists && File.readable?(creds_path)
      
      status = {
        credentials_path_set: creds_path.present?,
        credentials_file_exists: file_exists,
        credentials_file_readable: file_readable,
        project_id_set: project_id.present?,
        project_id_source: ENV['FCM_PROJECT_ID'].present? ? 'ENV' : (credentials_project_id.present? ? 'JSON' : 'none')
      }
      status[:credentials_path] = creds_path if creds_path.present?
      status[:project_id] = project_id if project_id.present?
      
      # Check JSON structure if readable
      if file_readable
        begin
          json = JSON.parse(File.read(creds_path))
          status[:json_has_project_id] = json.key?('project_id') || json.dig('project_info', 'project_id').present?
          status[:json_has_private_key] = json.key?('private_key')
          status[:json_has_client_email] = json.key?('client_email')
          status[:json_type] = json.key?('private_key') ? 'service_account' : (json.key?('project_info') ? 'client_config' : 'unknown')
          status[:json_validation_error] = validate_service_account_json
        rescue => e
          status[:json_parse_error] = e.message
        end
      end
      
      status
    end

    private

    def build_client
      return { error: 'FCM project_id or credentials not set' } unless configured?
      
      # Validate JSON structure before initializing FCM
      validation_error = validate_service_account_json
      return { error: validation_error } if validation_error
      
      # Pass file path so the gem can open (and re-open for token refresh) as needed.
      # We already strip quotes from ENV in credentials_path.
      fcm = FCM.new(credentials_path, project_id)
      { fcm: fcm }
    rescue StandardError => e
      { error: e.message }
    end

    def validate_service_account_json
      return 'Credentials file not readable' unless credentials_path && File.readable?(credentials_path)
      
      begin
        json = JSON.parse(File.read(credentials_path))
        
        # Check if it's a service account JSON (has private_key and client_email)
        if json.key?('private_key') && json.key?('client_email')
          return nil # Valid service account JSON
        end
        
        # Check if it's a client config file (google-services.json)
        if json.key?('project_info') && json.key?('client')
          return 'This appears to be a client-side google-services.json file. ' \
                 'You need a service account JSON file instead. ' \
                 'Download it from Firebase Console → Project Settings → Service accounts → Generate new private key'
        end
        
        return 'JSON file does not appear to be a valid service account file. ' \
               'Missing required fields: private_key, client_email'
      rescue JSON::ParserError => e
        return "Invalid JSON file: #{e.message}"
      rescue => e
        return "Error reading credentials file: #{e.message}"
      end
    end

    def project_id
      ENV['FCM_PROJECT_ID'].presence || credentials_project_id
    end

    def credentials_project_id
      return nil unless credentials_path && File.readable?(credentials_path)
      json = JSON.parse(File.read(credentials_path))
      # Service account JSON has 'project_id' field
      # Client google-services.json has 'project_info.project_id'
      json['project_id'] || json.dig('project_info', 'project_id')
    rescue StandardError => e
      Rails.logger.error "Failed to parse credentials JSON: #{e.message}" if defined?(Rails)
      nil
    end

    # True when FCM returns 404 NOT_FOUND with errorCode UNREGISTERED (token no longer valid).
    def fcm_response_unregistered?(response)
      return false unless response.is_a?(Hash) && response[:status_code] == 404
      body = response[:body]
      return false if body.blank?
      json = JSON.parse(body.to_s)
      details = json.dig('error', 'details')
      details.is_a?(Array) && details.any? { |d| d['errorCode'] == 'UNREGISTERED' }
    rescue JSON::ParserError, TypeError
      false
    end

    def credentials_path
      raw = ENV['GOOGLE_APPLICATION_CREDENTIALS'].presence
      # Strip surrounding quotes and whitespace (e.g. .env has GOOGLE_APPLICATION_CREDENTIALS="/path/to/file.json")
      path = raw.to_s.strip.gsub(/\A["'\s]+|["'\s]+\z/, '')
      return path if path.present? && File.file?(path)

      # If still not a valid file, try without any quote chars (in case .env kept literal quotes)
      path_no_quotes = raw.to_s.strip.delete('"').delete("'").strip
      return path_no_quotes if path_no_quotes.present? && File.file?(path_no_quotes)

      # Fallback: try common paths when ENV not set or path invalid
      [
        '/home/google-services.json',
        (Rails.root.join('config', 'google-services.json').to_s if defined?(Rails)),
        (Rails.root.join('config', 'firebase-service-account.json').to_s if defined?(Rails))
      ].compact.each do |p|
        return p if File.file?(p)
      end
      path_no_quotes.presence || path.presence
    end
  end
end
