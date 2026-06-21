# Factories for User model

FactoryBot.define do
  factory :user do
    tenant
    sequence(:email) { |n| "user#{n}@example.com" }
    first_name { "Test" }
    last_name { "User" }
    password { "TestPassword123!" }
    password_confirmation { "TestPassword123!" }
    status { :active }
    confirmed_at { Time.current }
    timezone { "Copenhagen" }
    locale { "en" }
    metadata { {} }
    preferences { {} }

    trait :unconfirmed do
      confirmed_at { nil }
      confirmation_token { SecureRandom.urlsafe_base64(64) }
      confirmation_sent_at { Time.current }
    end

    trait :pending do
      status { :pending }
    end

    trait :suspended do
      status { :suspended }
    end

    trait :disabled do
      status { :disabled }
    end

    trait :locked do
      failed_attempts { 5 }
      locked_at { Time.current }
      unlock_token { SecureRandom.urlsafe_base64(64) }
    end

    trait :admin do
      after(:create) do |user|
        admin_role = create(:role, name: "admin")
        create(:user_role, user: user, role: admin_role)
      end
    end

    trait :super_admin do
      after(:create) do |user|
        super_admin_role = create(:role, name: "super_admin")
        admin_role = create(:role, name: "admin")
        viewer_role = create(:role, name: "viewer")
        create(:user_role, user: user, role: super_admin_role)
        create(:user_role, user: user, role: admin_role)
        create(:user_role, user: user, role: viewer_role)
      end
    end

    trait :viewer do
      after(:create) do |user|
        viewer_role = create(:role, name: "viewer")
        create(:user_role, user: user, role: viewer_role)
      end
    end

    trait :with_roles do
      transient do
        role_names { ["viewer"] }
      end

      after(:create) do |user, evaluator|
        evaluator.role_names.each do |role_name|
          role = create(:role, name: role_name)
          create(:user_role, user: user, role: role)
        end
      end
    end

    trait :confirmed do
      confirmed_at { Time.current }
      confirmation_token { nil }
    end

    trait :with_phone do
      phone { Faker::PhoneNumber.phone_number }
    end

    trait :with_job_info do
      job_title { "Software Engineer" }
      department { "Engineering" }
    end

    trait :with_avatar do
      avatar_url { "https://example.com/avatars/default.png" }
    end

    trait :with_mfa do
      mfa_enabled { true }
      mfa_secret { ROTP::Base32.random_base32 }
      mfa_recovery_codes { Array.new(10) { SecureRandom.urlsafe_base64(16) } }
    end

    trait :with_long_password do
      password { SecureRandom.alphanumeric(20) }
      password_confirmation { password }
    end

    trait :with_api_token do
      after(:create) do |user|
        create(:api_token, user: user, name: "Default", token: SecureRandom.urlsafe_base64(64))
      end
    end

    trait :with_sessions do
      transient do
        session_count { 3 }
      end

      after(:create) do |user, evaluator|
        evaluator.session_count.times do
          create(:session, user: user, ip_address: Faker::Internet.ip_v4_address)
        end
      end
    end

    trait :with_audit_logs do
      transient do
        log_count { 5 }
      end

      after(:create) do |user, evaluator|
        evaluator.log_count.times do
          create(:audit_log, actor: user, action: "test_action", resource_type: "User", resource_id: user.id)
        end
      end
    end

    # Generate a user with specific attributes
    factory :user_with_attributes do
      email { "custom@example.com" }
      first_name { "Custom" }
      last_name { "User" }
      phone { "+1234567890" }
      job_title { "Developer" }
      department { "IT" }
      timezone { "UTC" }
      locale { "da" }
    end
  end
end

# Factory for Role
FactoryBot.define do
  factory :role do
    sequence(:name) { |n| "role_#{n}" }
    description { "A test role" }
    global { false }
    system { false }

    trait :system do
      system { true }
      global { true }
    end

    trait :global do
      global { true }
    end

    trait :admin do
      name { "admin" }
      description { "Can manage tenant resources" }
      system { true }
      global { true }
    end

    trait :super_admin do
      name { "super_admin" }
      description { "Full access to all features and tenants" }
      system { true }
      global { true }
    end

    trait :viewer do
      name { "viewer" }
      description { "Can view resources" }
      system { true }
      global { true }
    end

    trait :user do
      name { "user" }
      description { "Regular user with basic access" }
      system { true }
      global { true }
    end

    trait :guest do
      name { "guest" }
      description { "Limited access" }
      system { true }
      global { true }
    end

    trait :identity_admin do
      name { "identity_admin" }
      description { "Can manage identity providers and users" }
      system { false }
      global { false }
    end

    trait :migration_admin do
      name { "migration_admin" }
      description { "Can run AD migration jobs" }
      system { false }
      global { false }
    end

    trait :audit_admin do
      name { "audit_admin" }
      description { "Can view and export audit logs" }
      system { false }
      global { false }
    end

    trait :billing_admin do
      name { "billing_admin" }
      description { "Can manage billing and subscriptions" }
      system { false }
      global { false }
    end

    trait :with_permissions do
      permissions do
        [
          "read:users",
          "write:users",
          "delete:users",
          "read:tenants",
          "manage:settings"
        ]
      end
    end
  end
end

# Factory for UserRole
FactoryBot.define do
  factory :user_role do
    user
    role

    trait :with_expiry do
      expires_at { 1.year.from_now }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end

# Factory for Session
FactoryBot.define do
  factory :session do
    user
    ip_address { Faker::Internet.ip_v4_address }
    user_agent { "Mozilla/5.0" }
    status { :active }

    trait :revoked do
      status { :revoked }
      revoked_at { Time.current }
    end

    trait :expired do
      created_at { 1.day.ago }
      status { :expired }
    end
  end
end

# Factory for ApiToken
FactoryBot.define do
  factory :api_token do
    user
    sequence(:name) { |n| "Token #{n}" }
    token { SecureRandom.urlsafe_base64(64) }
    expires_at { 1.year.from_now }
    active { true }

    trait :inactive do
      active { false }
      revoked_at { Time.current }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end

# Factory for MFA Device
FactoryBot.define do
  factory :mfa_device do
    user
    device_type { :totp }
    name { "Default" }
    secret { ROTP::Base32.random_base32 }
    enabled { true }

    trait :webauthn do
      device_type { :webauthn }
      credential_id { SecureRandom.urlsafe_base64(32) }
      public_key { SecureRandom.urlsafe_base64(64) }
      sign_count { 0 }
    end

    trait :disabled do
      enabled { false }
    end
  end
end
