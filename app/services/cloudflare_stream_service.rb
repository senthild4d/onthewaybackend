# Cloudflare Stream Live API integration for live/feed streaming.
# Requires: CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_STREAM_API_TOKEN
# Optional: CLOUDFLARE_STREAM_CUSTOMER_CODE (for building viewer HLS URLs)
#
# Docs: https://developers.cloudflare.com/stream/stream-live/
# API: https://api.cloudflare.com/client/v4/accounts/{account_id}/stream/live_inputs
class CloudflareStreamService
  BASE_URL = 'https://api.cloudflare.com/client/v4'

  class << self
    # Create a live input. Broadcaster uses rtmps_url + stream_key in OBS/etc.
    # @param meta_name [String] optional display name for the stream
    # @param recording_mode [String] "automatic" | "off" | "manual"
    # @param prefer_low_latency [Boolean] enable Low-Latency HLS (beta)
    # @return [Hash] { success:, live_input:, error: }
    def create_live_input(meta_name: nil, recording_mode: 'automatic', prefer_low_latency: false)
      return { success: false, error: 'Cloudflare Stream not configured' } unless configured?

      body = {
        meta: meta_name.present? ? { name: meta_name.to_s } : {},
        recording: { mode: recording_mode },
        preferLowLatency: prefer_low_latency
      }.compact

      resp = post("/accounts/#{account_id}/stream/live_inputs", body)
      return { success: false, error: resp[:error] } if resp[:error]

      result = resp.dig(:result)
      return { success: false, error: 'No result in response' } unless result

      live_input = result.is_a?(Hash) ? result : {}
      { success: true, live_input: live_input }
    end

    # Get a live input by uid.
    # @param live_input_uid [String]
    # @return [Hash] { success:, live_input:, error: }
    def get_live_input(live_input_uid)
      return { success: false, error: 'Cloudflare Stream not configured' } unless configured?
      return { success: false, error: 'live_input_uid is blank' } if live_input_uid.blank?

      resp = get("/accounts/#{account_id}/stream/live_inputs/#{live_input_uid}")
      return { success: false, error: resp[:error] } if resp[:error]

      result = resp.dig(:result)
      return { success: false, error: 'No result in response' } unless result

      live_input = result.is_a?(Hash) ? result : {}
      { success: true, live_input: live_input }
    end

    # Delete a live input.
    # @param live_input_uid [String]
    # @return [Hash] { success:, error: }
    def delete_live_input(live_input_uid)
      return { success: false, error: 'Cloudflare Stream not configured' } unless configured?
      return { success: false, error: 'live_input_uid is blank' } if live_input_uid.blank?

      resp = delete("/accounts/#{account_id}/stream/live_inputs/#{live_input_uid}")
      return { success: false, error: resp[:error] } if resp[:error]

      { success: true }
    end

    # Build HLS viewer URL for a live input (for in-app or web player).
    # Requires CLOUDFLARE_STREAM_CUSTOMER_CODE (find in Stream dashboard or API).
    # @param live_input_uid [String]
    # @param low_latency [Boolean] add ?protocol=llhls
    # @return [String, nil] URL or nil if not configured
    def viewer_hls_url(live_input_uid, low_latency: false)
      return nil if live_input_uid.blank?
      code = customer_code
      return nil if code.blank?

      base = "https://customer-#{code}.cloudflarestream.com/#{live_input_uid}/manifest/video.m3u8"
      low_latency ? "#{base}?protocol=llhls" : base
    end

    def configured?
      account_id.present? && api_token.present?
    end

    def configuration_status
      {
        account_id_set: account_id.present?,
        api_token_set: api_token.present?,
        customer_code_set: customer_code.present?
      }
    end

    private

    def account_id
      ENV['CLOUDFLARE_ACCOUNT_ID'].to_s.strip.presence
    end

    def api_token
      ENV['CLOUDFLARE_STREAM_API_TOKEN'].to_s.strip.presence
    end

    def customer_code
      ENV['CLOUDFLARE_STREAM_CUSTOMER_CODE'].to_s.strip.presence
    end

    def get(path)
      request(:get, path)
    end

    def post(path, body)
      request(:post, path, body: body)
    end

    def delete(path)
      request(:delete, path)
    end

    def request(method, path, body: nil)
      uri = URI("#{BASE_URL}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.open_timeout = 15
      http.read_timeout = 15

      req = case method
            when :get then Net::HTTP::Get.new(uri)
            when :post then Net::HTTP::Post.new(uri)
            when :delete then Net::HTTP::Delete.new(uri)
            else Net::HTTP::Get.new(uri)
            end
      req['Authorization'] = "Bearer #{api_token}"
      req['Content-Type'] = 'application/json'
      req.body = body.to_json if body && (method == :post)

      resp = http.request(req)
      data = begin
        JSON.parse(resp.body || '{}')
      rescue JSON::ParserError
        {}
      end
      data = data.with_indifferent_access if data.is_a?(Hash)
      success = data['success'] == true
      return { error: data['errors']&.first&.dig('message') || "HTTP #{resp.code}" } unless success

      data
    rescue StandardError => e
      Rails.logger.error "CloudflareStreamService #{method} #{path}: #{e.message}"
      { error: e.message }
    end
  end
end
