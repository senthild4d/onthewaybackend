# Trigger a test FCM push notification to a device token.
#
# Usage:
#   rake "fcm:send[YOUR_FCM_TOKEN,Title,Body text here]"
#
# Example with your token:
#   rake "fcm:send[c3mnV0V7S0Grcfo2HsA6-h:APA91bFsPdBW-bf3RM41hBZTUcpgspU10y3FO0jwThnykAU5pSx8UvFfRG1fn8LyVIdPPnrtAm0dj-ceRutN3du4MLxYHBx9iZL3wtgIs_51rgmaXjxJN1o,Test,Hello from Vibes]"
#
# Prerequisites:
#   1. Firebase project with Cloud Messaging enabled
#   2. Service account key JSON downloaded from Firebase Console → Project Settings → Service accounts
#   3. Set in .env or environment:
#      GOOGLE_APPLICATION_CREDENTIALS=/path/to/your-service-account.json
#      FCM_PROJECT_ID=your-firebase-project-id  (optional if in the JSON)
#
namespace :fcm do
  desc "Send a test push notification to an FCM token. Usage: rake 'fcm:send[TOKEN,Title,Body]'"
  task :send, %i[token title body] => :environment do |_t, args|
    # Strip quotes from path (dotenv sometimes keeps them, which breaks File.open)
    if ENV['GOOGLE_APPLICATION_CREDENTIALS'].present?
      stripped = ENV['GOOGLE_APPLICATION_CREDENTIALS'].to_s.strip.delete('"').delete("'").strip
      ENV['GOOGLE_APPLICATION_CREDENTIALS'] = stripped if stripped.present?
    end

    # Fallback: if .env didn't set credentials, try common paths so "rake fcm:send" works without export
    if ENV['GOOGLE_APPLICATION_CREDENTIALS'].blank?
      [
        '/home/google-services.json',
        Rails.root.join('config', 'google-services.json').to_s,
        Rails.root.join('config', 'firebase-service-account.json').to_s
      ].each do |path|
        if File.file?(path.to_s)
          ENV['GOOGLE_APPLICATION_CREDENTIALS'] = path.to_s
          break
        end
      end
    end
    if ENV['FCM_PROJECT_ID'].blank? && ENV['GOOGLE_APPLICATION_CREDENTIALS'].present?
      begin
        creds_path = ENV['GOOGLE_APPLICATION_CREDENTIALS'].to_s.strip.gsub(/\A["']|["']\z/, '')
        json = JSON.parse(File.read(creds_path))
        ENV['FCM_PROJECT_ID'] = json['project_id'] if json['project_id'].present?
      rescue StandardError
        # ignore
      end
    end

    token = args[:token]
    title = args[:title] || 'Vibes'
    body  = args[:body] || 'Test notification'

    if token.blank?
      puts "Usage: rake \"fcm:send[FCM_TOKEN,Title,Body]\""
      puts "Example: rake \"fcm:send[c3mnV0V7S0Grcfo2HsA6-h:APA91b...,Test,Hello]\""
      exit 1
    end

    unless FcmService.configured?
      puts "FCM is not configured. Current status:"
      status = FcmService.configuration_status
      status.each do |key, value|
        puts "  #{key}: #{value.inspect}"
      end
      
      # Check JSON validation from status
      if status[:json_validation_error]
        puts "\n⚠️  JSON File Issue:"
        puts "  #{status[:json_validation_error]}"
      end
      
      puts "\nRequired:"
      puts "  GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json"
      puts "  FCM_PROJECT_ID=your-project-id  (optional if project_id is in the JSON file)"
      puts "\nCurrent ENV:"
      puts "  GOOGLE_APPLICATION_CREDENTIALS=#{ENV['GOOGLE_APPLICATION_CREDENTIALS'].inspect}"
      puts "  FCM_PROJECT_ID=#{ENV['FCM_PROJECT_ID'].inspect}"
      puts "\n📖 How to get the correct file:"
      puts "  1. Go to Firebase Console → Your Project"
      puts "  2. Click ⚙️ Settings → Project Settings"
      puts "  3. Go to 'Service accounts' tab"
      puts "  4. Click 'Generate new private key'"
      puts "  5. Download the JSON file (it will have private_key and client_email)"
      puts "  6. Save it on your server and update GOOGLE_APPLICATION_CREDENTIALS"
      exit 1
    end

    # Debug: show which credentials path is used (helps when 401 persists)
    status = FcmService.configuration_status
    puts "Using credentials: #{status[:credentials_path].inspect}" if status[:credentials_path]

    result = FcmService.send_to_token(token, title: title, body: body)
    if result[:success]
      puts "Notification sent successfully."
    else
      puts "Failed: #{result[:error] || result[:response]}"
      # Helpful hint for 401 (invalid or missing credentials)
      if result[:response].is_a?(Hash) && result[:response][:status_code] == 401
        puts "\n🔑 401 UNAUTHENTICATED means Firebase did not accept your credentials."
        puts "   Credentials path used: #{status[:credentials_path].inspect}"
        puts "   Try in the same shell: export GOOGLE_APPLICATION_CREDENTIALS=#{status[:credentials_path] || '/home/google-services.json'}"
        puts "   Then run this rake task again. If it works with export, .env may not be loaded for this process."
        puts "   Fix:"
        puts "   1. Ensure GOOGLE_APPLICATION_CREDENTIALS points to a SERVICE ACCOUNT JSON file"
        puts "   2. Deploy latest code (FcmService uses file path and strips quotes from .env)."
        puts "   3. See docs/FCM_401_TROUBLESHOOTING.md"
      end
      exit 1
    end
  end
end
