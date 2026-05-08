FactoryBot.define do
  factory :otp do
    code { '123456' }
    expires_at { 15.minutes.from_now }
    verified { false }
    attempts { 0 }

    trait :with_phone do
      sequence(:phone) { |n| "987654#{n.to_s.rjust(4, '0')}" }
      email { nil }
    end

    trait :with_email do
      phone { nil }
      sequence(:email) { |n| "otp#{n}@example.com" }
    end

    trait :expired do
      expires_at { 1.minute.ago }
    end

    trait :verified do
      verified { true }
    end

    trait :max_attempts do
      attempts { 5 }
    end
  end
end

