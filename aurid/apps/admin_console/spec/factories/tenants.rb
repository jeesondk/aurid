# Factories for Tenant model

FactoryBot.define do
  factory :tenant do
    sequence(:name) { |n| "Tenant #{n}" }
    sequence(:domain) { |n| "tenant#{n}.aurid.io" }
    status { :active }
    tier { :basic }
    description { "A test tenant" }
    max_users { 100 }
    metadata { {} }
    custom_branding { {} }

    trait :default do
      name { "Default" }
      domain { "aurid.io" }
      tier { :enterprise }
      status { :active }
    end

    trait :pending do
      status { :pending }
    end

    trait :suspended do
      status { :suspended }
    end

    trait :cancelled do
      status { :cancelled }
    end

    trait :free_tier do
      tier { :free }
      max_users { 10 }
    end

    trait :professional_tier do
      tier { :professional }
      max_users { 1000 }
    end

    trait :enterprise_tier do
      tier { :enterprise }
      max_users { nil } # Unlimited
    end

    trait :with_billing do
      billing_email { "billing@#{domain}" }
      billing_address { "123 Main St" }
      billing_city { "Copenhagen" }
      billing_state { "Denmark" }
      billing_zip { "1000" }
      billing_country { "DK" }
      vat_number { "DK12345678" }
    end

    trait :with_api_key do
      api_key { SecureRandom.urlsafe_base64(64) }
      api_key_digest { Digest::SHA256.hexdigest(api_key) }
    end

    trait :with_settings do
      after(:create) do |tenant|
        create(:tenant_setting, tenant: tenant, key: "audit_logging_enabled", value: "true")
        create(:tenant_setting, tenant: tenant, key: "ad_migration_enabled", value: "true")
        create(:tenant_setting, tenant: tenant, key: "mfa_required", value: "false")
      end
    end

    trait :with_users do
      transient do
        user_count { 5 }
      end

      after(:create) do |tenant, evaluator|
        create_list(:user, evaluator.user_count, tenant: tenant)
      end
    end

    trait :with_domains do
      transient do
        domain_count { 3 }
      end

      after(:create) do |tenant, evaluator|
        evaluator.domain_count.times do |n|
          create(:domain, tenant: tenant, name: "domain#{n}.#{tenant.domain}")
        end
      end
    end

    trait :with_applications do
      transient do
        app_count { 2 }
      end

      after(:create) do |tenant, evaluator|
        evaluator.app_count.times do |n|
          create(:application, tenant: tenant, name: "App #{n}")
        end
      end
    end
  end
end

# Factory for TenantSetting
FactoryBot.define do
  factory :tenant_setting do
    tenant
    sequence(:key) { |n| "setting_#{n}" }
    value { "true" }

    trait :audit_logging_enabled do
      key { "audit_logging_enabled" }
      value { "true" }
    end

    trait :audit_logging_disabled do
      key { "audit_logging_enabled" }
      value { "false" }
    end

    trait :ad_migration_enabled do
      key { "ad_migration_enabled" }
      value { "true" }
    end

    trait :mfa_required do
      key { "mfa_required" }
      value { "true" }
    end

    trait :max_users do
      key { "max_users" }
      value { "1000" }
    end
  end
end

# Factory for Domain
FactoryBot.define do
  factory :domain do
    tenant
    sequence(:name) { |n| "domain#{n}.example.com" }
    verified { false }
    primary { false }

    trait :verified do
      verified { true }
    end

    trait :primary do
      primary { true }
      verified { true }
    end

    trait :with_ssl do
      ssl_certificate { "-----BEGIN CERTIFICATE-----\nMII..." }
      ssl_private_key { "-----BEGIN PRIVATE KEY-----\nMII..." }
    end
  end
end

# Factory for Application
FactoryBot.define do
  factory :application do
    tenant
    sequence(:name) { |n| "Application #{n}" }
    sequence(:client_id) { |n| "client_#{n}" }
    client_secret { SecureRandom.urlsafe_base64(64) }
    app_type { :oidc }
    redirect_uris { ["https://app.example.com/callback"] }
    post_logout_redirect_uris { ["https://app.example.com/logout"] }
    enabled { true }

    trait :saml do
      app_type { :saml }
      entity_id { "https://app.example.com/saml/metadata" }
      acs_url { "https://app.example.com/saml/acs" }
    end

    trait :ldap do
      app_type { :ldap }
      bind_dn { "cn=app,dc=example,dc=com" }
      bind_password { SecureRandom.urlsafe_base64(32) }
      base_dn { "ou=users,dc=example,dc=com" }
    end

    trait :disabled do
      enabled { false }
    end

    trait :with_credentials do
      client_id { SecureRandom.urlsafe_base64(32) }
      client_secret { SecureRandom.urlsafe_base64(64) }
    end
  end
end
