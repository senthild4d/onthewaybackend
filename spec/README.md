# RSpec Test Suite for Vibes API

This directory contains comprehensive RSpec tests for the Vibes API, with focus on the UsersController endpoints.

## Setup

### 1. Add Required Gems

Add these gems to your `Gemfile` in the `:test` group:

```ruby
group :development, :test do
  gem 'rspec-rails', '~> 6.0'
  gem 'factory_bot_rails', '~> 6.4'
  gem 'faker', '~> 3.2'
end

group :test do
  gem 'database_cleaner-active_record', '~> 2.1'
  gem 'shoulda-matchers', '~> 5.3'
  gem 'simplecov', require: false
end
```

### 2. Install Dependencies

```bash
bundle install
```

### 3. Setup Test Database

```bash
RAILS_ENV=test bin/rails db:create
RAILS_ENV=test bin/rails db:schema:load
RAILS_ENV=test bin/rails db:migrate
```

## Running Tests

### Run All Tests

```bash
bundle exec rspec
```

### Run Specific Test File

```bash
bundle exec rspec spec/requests/api/v1/users_controller_spec.rb
```

### Run Specific Test

```bash
bundle exec rspec spec/requests/api/v1/users_controller_spec.rb:10
```

### Run Model Tests Only

```bash
bundle exec rspec spec/models
```

### Run Request Tests Only

```bash
bundle exec rspec spec/requests
```

## Test Coverage

### UsersController Endpoints Covered

✅ **GET /api/v1/users/me**
- Authenticated user retrieval
- Unauthorized access handling
- Avatar URL and bio inclusion

✅ **GET /api/v1/users/:id**
- Public user profile retrieval
- User not found handling
- Profile stats inclusion

✅ **PATCH /api/v1/users/me**
- Valid profile updates
- Email/phone update prevention
- Username validation
- Invalid params handling

✅ **POST /api/v1/users/me/upload_profile_picture**
- Valid image upload
- Missing file handling
- Invalid file type rejection
- File size validation
- Profile picture URL return

✅ **POST /api/v1/users/me/change_email**
- Valid email change request
- OTP creation
- Duplicate email detection
- Invalid email rejection

✅ **POST /api/v1/users/me/verify_email_change**
- Valid OTP verification
- Email update on success
- Invalid OTP handling
- OTP verification marking

✅ **POST /api/v1/users/me/change_phone**
- Valid phone change request
- OTP creation
- Duplicate phone detection
- Invalid phone rejection

✅ **POST /api/v1/users/me/unlink_email**
- Email unlinking with phone present
- Prevention without phone
- Error handling for missing email

✅ **POST /api/v1/users/me/unlink_phone**
- Phone unlinking with email present
- Prevention without email
- Error handling for missing phone

✅ **POST /api/v1/users/me/deactivate**
- Account deactivation with reason
- Deactivation record creation
- Reason normalization
- Optional feedback storage
- Status change to disabled

✅ **POST /api/v1/users/me/reactivate**
- Account reactivation
- Deactivation record update
- Reactivation metadata storage
- Error when not deactivated

✅ **GET /api/v1/users/search**
- User search by name/username
- Query requirement validation
- Pagination support
- Limit/offset handling

### Model Tests Covered

✅ **User Model**
- Associations
- Validations (email, phone, username, date_of_birth)
- Enums (role, status)
- Callbacks (downcase_email, normalize_phone)
- Avatar URL methods
- Deactivation methods
- Follow/unfollow functionality

✅ **UserDeactivation Model**
- Associations
- Validations
- Scopes (active, reactivated, by_reason)
- Analytics methods
- Instance methods (active?, reactivate!, duration_days)
- Human-readable reason conversion

## Test Structure

```
spec/
├── factories/                    # FactoryBot factories
│   ├── users.rb                 # User factory with traits
│   ├── user_deactivations.rb    # UserDeactivation factory
│   └── otps.rb                  # OTP factory
├── fixtures/                     # Test fixture files
│   └── files/
│       ├── test_image.png       # Test image for uploads
│       └── test_document.pdf    # Test PDF for validation
├── models/                       # Model specs
│   ├── user_spec.rb             # User model tests
│   └── user_deactivation_spec.rb # UserDeactivation model tests
├── requests/                     # Request/controller specs
│   └── api/
│       └── v1/
│           └── users_controller_spec.rb  # UsersController tests
├── support/                      # Helper modules
│   ├── auth_helper.rb           # Authentication helpers
│   ├── json_helper.rb           # JSON response helpers
│   └── database_cleaner.rb      # Database cleaner config
├── rails_helper.rb              # Rails test configuration
└── spec_helper.rb               # RSpec configuration
```

## Writing New Tests

### Example: Testing a New Endpoint

```ruby
describe 'POST /api/v1/users/me/new_endpoint' do
  context 'when authenticated' do
    let(:params) { { key: 'value' } }
    
    before do
      post '/api/v1/users/me/new_endpoint',
           params: params,
           headers: headers,
           as: :json
    end

    it 'returns http success' do
      expect(response).to have_http_status(:success)
    end

    it 'returns expected data' do
      expect(json[:data][:key]).to eq('expected_value')
    end
  end

  context 'when not authenticated' do
    before { post '/api/v1/users/me/new_endpoint' }

    it 'returns unauthorized' do
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
```

### Using Factories

```ruby
# Create a user
user = create(:user)

# Create with traits
artist = create(:user, :artist)
disabled_user = create(:user, :disabled)

# Create without saving
user = build(:user)

# Override attributes
user = create(:user, email: 'custom@example.com')
```

### Using Helpers

```ruby
# Authentication
headers = auth_headers(user)

# JSON response parsing
json = json_response
data = json_data
message = json_message
errors = json_errors
```

## Continuous Integration

Add to your CI pipeline:

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.4.4
      - name: Install dependencies
        run: bundle install
      - name: Setup database
        run: |
          RAILS_ENV=test bin/rails db:create
          RAILS_ENV=test bin/rails db:schema:load
      - name: Run tests
        run: bundle exec rspec
```

## Troubleshooting

### Common Issues

**Issue**: `LoadError: cannot load such file -- factory_bot_rails`
**Solution**: Run `bundle install`

**Issue**: `ActiveRecord::PendingMigrationError`
**Solution**: Run `RAILS_ENV=test bin/rails db:migrate`

**Issue**: Tests fail with authentication errors
**Solution**: Ensure JsonWebToken service is properly configured

**Issue**: File upload tests fail
**Solution**: Ensure fixture files exist in `spec/fixtures/files/`

## Best Practices

1. ✅ **Test behavior, not implementation**
2. ✅ **Use factories instead of fixtures**
3. ✅ **Test happy path and edge cases**
4. ✅ **Keep tests DRY with shared contexts**
5. ✅ **Use descriptive test names**
6. ✅ **Mock external services**
7. ✅ **Clean database between tests**

## Coverage Report

To generate coverage report, add to `spec_helper.rb`:

```ruby
require 'simplecov'
SimpleCov.start 'rails'
```

Then run tests:

```bash
bundle exec rspec
open coverage/index.html
```

## Next Steps

1. Run the test suite to catch existing 500 errors
2. Fix failing tests by updating controller logic
3. Add tests for other controllers (Events, Venues, etc.)
4. Set up CI/CD pipeline
5. Monitor test coverage and aim for >80%

