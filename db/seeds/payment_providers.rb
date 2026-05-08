# Payment Provider Seeds
# Run with: rails db:seed:payment_providers

puts "Creating payment providers..."

# Stripe Payment Provider
stripe = PaymentProvider.find_or_create_by(name: 'stripe') do |provider|
  provider.provider_type = 'stripe'
  provider.status = 'inactive' # Set to 'active' after adding credentials
  provider.is_default = true
  provider.description = 'Stripe payment processing'
  provider.credentials = {
    api_key: ENV['STRIPE_API_KEY'] || '',
    secret_key: ENV['STRIPE_SECRET_KEY'] || '',
    webhook_secret: ENV['STRIPE_WEBHOOK_SECRET'] || ''
  }.to_json
  provider.settings = {
    supported_currencies: ['USD', 'EUR', 'GBP', 'CAD', 'AUD'],
    supported_payment_methods: ['credit_card', 'debit_card', 'apple_pay', 'google_pay'],
    fee_structure: {
      percentage: 2.9,
      fixed: 0.30
    }
  }.to_json
end

puts "✓ Stripe provider created/updated"

# PayPal Payment Provider
paypal = PaymentProvider.find_or_create_by(name: 'paypal') do |provider|
  provider.provider_type = 'paypal'
  provider.status = 'inactive' # Set to 'active' after adding credentials
  provider.is_default = false
  provider.description = 'PayPal payment processing'
  provider.credentials = {
    client_id: ENV['PAYPAL_CLIENT_ID'] || '',
    client_secret: ENV['PAYPAL_CLIENT_SECRET'] || '',
    webhook_secret: ENV['PAYPAL_WEBHOOK_SECRET'] || '',
    mode: ENV['PAYPAL_MODE'] || 'sandbox' # sandbox or live
  }.to_json
  provider.settings = {
    supported_currencies: ['USD', 'EUR', 'GBP', 'CAD', 'AUD'],
    supported_payment_methods: ['paypal'],
    fee_structure: {
      percentage: 3.4,
      fixed: 0.30
    }
  }.to_json
end

puts "✓ PayPal provider created/updated"

# Crypto Payment Provider
crypto = PaymentProvider.find_or_create_by(name: 'crypto') do |provider|
  provider.provider_type = 'crypto'
  provider.status = 'active'
  provider.is_default = false
  provider.description = 'Cryptocurrency payment processing'
  provider.credentials = {
    api_key: ENV['CRYPTO_API_KEY'] || '',
    api_secret: ENV['CRYPTO_API_SECRET'] || '',
    webhook_secret: ENV['CRYPTO_WEBHOOK_SECRET'] || ''
  }.to_json
  provider.settings = {
    supported_currencies: ['BTC', 'ETH', 'USDT', 'USDC', 'SOL', 'MATIC', 'BNB'],
    supported_payment_methods: ['crypto'],
    fee_structure: {
      percentage: 1.0,
      fixed: 0.0
    },
    networks: {
      BTC: 'bitcoin',
      ETH: 'ethereum',
      USDT: ['ethereum', 'tron'],
      USDC: ['ethereum', 'solana'],
      SOL: 'solana',
      MATIC: 'polygon',
      BNB: 'binance_smart_chain'
    }
  }.to_json
end

puts "✓ Crypto provider created/updated"

puts "\nPayment providers seeded successfully!"
puts "\nNote: Update provider credentials in the database or via environment variables"
puts "Set provider status to 'active' after adding valid credentials"


