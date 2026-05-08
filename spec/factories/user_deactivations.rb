FactoryBot.define do
  factory :user_deactivation do
    association :user
    reason { "privacy_security" }
    additional_feedback { "Test feedback" }
    deactivated_at { Time.current }
    reactivated_at { nil }
    reactivated_by { nil }
    reactivation_notes { nil }

    trait :active do
      reactivated_at { nil }
    end

    trait :reactivated do
      reactivated_at { Time.current }
      reactivated_by { "user" }
      reactivation_notes { "Changed my mind" }
    end

    trait :leaving_temporarily do
      reason { "leaving_temporarily" }
    end

    trait :privacy_security do
      reason { "privacy_security" }
    end

    trait :trouble_getting_started do
      reason { "trouble_getting_started" }
    end

    trait :multiple_accounts do
      reason { "multiple_accounts" }
    end

    trait :other do
      reason { "other" }
    end
  end
end

