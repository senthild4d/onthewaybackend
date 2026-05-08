FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:phone) { |n| "123456#{n.to_s.rjust(4, '0')}" }
    sequence(:username) { |n| "user#{n}" }
    name { "Test User" }
    password { "Password123" }
    password_confirmation { "Password123" }
    role { "consumer" }
    status { "active" }
    date_of_birth { 25.years.ago.to_date }
    bio { "Test bio" }
    preferences { {} }

    trait :active do
      status { "active" }
    end

    trait :disabled do
      status { "disabled" }
    end

    trait :consumer do
      role { "consumer" }
    end

    trait :artist do
      role { "artist" }
    end

    trait :venue_manager do
      role { "venue_manager" }
    end

    trait :admin do
      role { "admin" }
    end

    trait :with_phone_only do
      email { nil }
    end

    trait :with_email_only do
      phone { nil }
    end

    trait :with_profile_picture do
      after(:create) do |user|
        user.profile_picture.attach(
          io: File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_image.png')),
          filename: 'test_image.png',
          content_type: 'image/png'
        )
      end
    end
  end
end

