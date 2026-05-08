# Payment System Documentation

## Overview

The Vibes platform includes a comprehensive wallet and payment system with support for multiple payment providers, cryptocurrencies, and payment methods.

## Features

- **Multi-Currency Wallets**: Support for multiple fiat currencies (USD, EUR, GBP, etc.)
- **Multiple Payment Providers**: Stripe, PayPal, Crypto, and extensible architecture
- **Cryptocurrency Support**: BTC, ETH, USDT, USDC, SOL, MATIC, BNB
- **Payment Methods**: Credit cards, debit cards, bank transfers, crypto wallets, PayPal, Apple Pay, Google Pay
- **Transaction History**: Complete audit trail of all transactions
- **Webhook Integration**: Real-time updates from payment providers
- **Admin Interface**: Manage payment providers and settings

## Database Models

### Wallet
- Stores user wallet balances by currency
- Tracks locked balance for pending transactions
- Status: active, suspended, closed

### PaymentTransaction
- Records all payment operations
- Types: deposit, withdrawal, payment, refund, transfer
- Status: pending, processing, completed, failed, cancelled, refunded
- Links to payment providers and references (events, bookings, etc.)

### CryptoWallet
- Stores user cryptocurrency wallet addresses
- Supports multiple cryptocurrencies and networks
- Types: external, internal

### PaymentProvider
- Configuration for payment providers
- Stores credentials securely (JSONB)
- Settings for fees, supported currencies, etc.

### PaymentMethod
- Saved payment methods for users
- Cards, bank accounts, crypto wallets, PayPal accounts
- Default payment method support

## API Endpoints

### Wallets
- `GET /api/v1/wallets` - List user wallets
- `GET /api/v1/wallets/:id` - Get wallet details
- `GET /api/v1/wallets/by_currency/:currency` - Get wallet by currency

### Payments
- `POST /api/v1/payments/deposit` - Initiate deposit
- `POST /api/v1/payments/withdraw` - Initiate withdrawal
- `POST /api/v1/payments/pay` - Process payment

### Payment Transactions
- `GET /api/v1/payment_transactions` - List transactions (with filters)
- `GET /api/v1/payment_transactions/:id` - Get transaction details
- `POST /api/v1/payment_transactions/:id/refund` - Process refund

### Payment Methods
- `GET /api/v1/payment_methods` - List saved payment methods
- `POST /api/v1/payment_methods` - Add payment method
- `PATCH /api/v1/payment_methods/:id` - Update payment method
- `DELETE /api/v1/payment_methods/:id` - Remove payment method
- `POST /api/v1/payment_methods/:id/set_default` - Set as default

### Crypto Wallets
- `GET /api/v1/crypto_wallets` - List crypto wallets
- `POST /api/v1/crypto_wallets` - Add crypto wallet
- `PATCH /api/v1/crypto_wallets/:id` - Update crypto wallet
- `DELETE /api/v1/crypto_wallets/:id` - Archive crypto wallet

### Webhooks
- `POST /api/v1/webhooks/stripe` - Stripe webhook handler
- `POST /api/v1/webhooks/paypal` - PayPal webhook handler
- `POST /api/v1/webhooks/crypto` - Crypto webhook handler

### Admin
- `GET /api/v1/admin/payment_providers` - List payment providers
- `POST /api/v1/admin/payment_providers` - Create payment provider
- `PATCH /api/v1/admin/payment_providers/:id` - Update payment provider
- `POST /api/v1/admin/payment_providers/:id/activate` - Activate provider
- `POST /api/v1/admin/payment_providers/:id/deactivate` - Deactivate provider

## Payment Service Architecture

### PaymentService
Main service class that handles all payment operations:
- Routes to appropriate payment provider
- Manages wallet balances
- Calculates fees
- Creates transaction records

### Payment Providers

#### BasePaymentProvider
Abstract base class for all payment providers.

#### StripePaymentProvider
- Credit/debit card processing
- Payment intents
- Transfers and payouts
- Refunds

#### PaypalPaymentProvider
- PayPal payments
- Payouts
- Refunds

#### CryptoPaymentProvider
- Cryptocurrency payments
- Wallet address validation
- Network fee calculation
- Blockchain confirmation tracking

## Setup Instructions

### 1. Install Gems
```bash
bundle install
```

### 2. Run Migrations
```bash
rails db:migrate
```

### 3. Seed Payment Providers
```bash
rails db:seed
# Or load specific seed file:
load Rails.root.join('db', 'seeds', 'payment_providers.rb')
```

### 4. Configure Environment Variables

Add to your `.env` or environment:

```bash
# Stripe
STRIPE_API_KEY=sk_test_...
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

# PayPal
PAYPAL_CLIENT_ID=...
PAYPAL_CLIENT_SECRET=...
PAYPAL_WEBHOOK_SECRET=...
PAYPAL_MODE=sandbox # or 'live'

# Crypto (if using external API)
CRYPTO_API_KEY=...
CRYPTO_API_SECRET=...
CRYPTO_WEBHOOK_SECRET=...
```

### 5. Activate Payment Providers

Update payment provider status in database:
```ruby
stripe = PaymentProvider.find_by(name: 'stripe')
stripe.update(status: 'active', credentials: { api_key: '...', secret_key: '...' })
```

### 6. Configure Webhooks

Set webhook URLs in payment provider dashboards:
- Stripe: `https://your-domain.com/api/v1/webhooks/stripe`
- PayPal: `https://your-domain.com/api/v1/webhooks/paypal`
- Crypto: `https://your-domain.com/api/v1/webhooks/crypto`

## Usage Examples

### Deposit Funds
```ruby
POST /api/v1/payments/deposit
{
  "amount": 100.00,
  "currency": "USD",
  "payment_method": "credit_card",
  "provider": "stripe",
  "metadata": {
    "payment_method_id": "pm_1234"
  }
}
```

### Process Payment
```ruby
POST /api/v1/payments/pay
{
  "amount": 50.00,
  "currency": "USD",
  "payment_method": "credit_card",
  "reference_type": "Booking",
  "reference_id": "booking-uuid",
  "provider": "stripe"
}
```

### Crypto Withdrawal
```ruby
POST /api/v1/payments/withdraw
{
  "amount": 0.1,
  "currency": "BTC",
  "payment_method": "crypto",
  "destination": "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
  "provider": "crypto",
  "metadata": {
    "crypto_currency": "BTC",
    "network": "bitcoin"
  }
}
```

## Security Considerations

1. **Credentials Storage**: Payment provider credentials are stored in JSONB fields. In production, consider encryption.
2. **Webhook Verification**: All webhooks verify signatures before processing.
3. **Balance Locking**: Withdrawals lock balance until confirmed.
4. **Transaction Validation**: All transactions are validated before processing.
5. **Admin Access**: Payment provider management requires admin role.

## Fee Structure

Default fees (configurable per provider):
- Credit/Debit Cards: 2.9% + $0.30
- PayPal: 3.4% + $0.30
- Crypto: 1.0%
- Bank Transfer: 0%

Network fees for crypto transactions are calculated separately.

## Error Handling

All payment operations return structured responses:
- Success: `{ success: true, transaction: {...}, result: {...} }`
- Failure: `{ success: false, transaction: {...}, error: "error message" }`

Common errors:
- `InsufficientFundsError`: Not enough balance
- `InvalidProviderError`: Provider not found or inactive
- `PaymentError`: General payment processing error

## Testing

Use test credentials from payment providers:
- Stripe: Use test API keys (sk_test_...)
- PayPal: Use sandbox mode
- Crypto: Use testnet addresses

## Future Enhancements

- [ ] Recurring payments/subscriptions
- [ ] Payment method tokenization
- [ ] Multi-signature crypto wallets
- [ ] Payment splitting
- [ ] Escrow services
- [ ] Payment analytics dashboard

