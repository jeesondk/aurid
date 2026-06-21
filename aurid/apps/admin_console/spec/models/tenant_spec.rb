# Tenant Model Tests

require "rails_helper"

RSpec.describe Tenant, type: :model do
  describe "validations" do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:domain) }
    it { should validate_uniqueness_of(:name).case_insensitive }
    it { should validate_uniqueness_of(:domain).case_insensitive }
    it { should validate_length_of(:name).is_at_most(255) }
    
    it { should allow_value("pending").for(:status) }
    it { should allow_value("active").for(:status) }
    it { should allow_value("suspended").for(:status) }
    it { should allow_value("cancelled").for(:status) }
    it { should_not allow_value("invalid").for(:status) }
    
    it { should allow_value("free").for(:tier) }
    it { should allow_value("basic").for(:tier) }
    it { should allow_value("professional").for(:tier) }
    it { should allow_value("enterprise").for(:tier) }
    it { should_not allow_value("invalid").for(:tier) }
    
    it { should allow_value(nil).for(:max_users) }
    it { should allow_value(1).for(:max_users) }
    it { should allow_value(1000).for(:max_users) }
    it { should_not allow_value(0).for(:max_users) }
    it { should_not allow_value(-1).for(:max_users) }
    
    it { should allow_value("test@example.com").for(:billing_email) }
    it { should_not allow_value("invalid-email").for(:billing_email) }
  end

  describe "associations" do
    it { should have_many(:users).dependent(:nullify) }
    it { should have_many(:domains).dependent(:destroy) }
    it { should have_many(:applications).dependent(:destroy) }
    it { should have_many(:audit_logs).dependent(:destroy) }
    it { should have_many(:settings).class_name("TenantSetting").dependent(:destroy) }
    it { should have_many(:migration_jobs).dependent(:destroy) }
    it { should have_many(:identity_providers).dependent(:destroy) }
  end

  describe "scopes" do
    let!(:tenant1) { create(:tenant, name: "Alpha") }
    let!(:tenant2) { create(:tenant, name: "Beta", status: :pending) }
    let!(:tenant3) { create(:tenant, name: "Gamma", status: :suspended) }
    let!(:tenant4) { create(:tenant, name: "Delta", status: :active) }

    describe ".by_status" do
      it "filters by status" do
        expect(Tenant.by_status(:active)).to include(tenant1, tenant4)
        expect(Tenant.by_status(:active)).not_to include(tenant2, tenant3)
      end
    end

    describe ".active" do
      it "returns only active tenants" do
        expect(Tenant.active).to include(tenant1, tenant4)
        expect(Tenant.active).not_to include(tenant2, tenant3)
      end
    end

    describe ".ordered_by_name" do
      it "orders tenants by name" do
        expect(Tenant.ordered_by_name.pluck(:name)).to eq(["Alpha", "Beta", "Delta", "Gamma"])
      end
    end

    describe ".search_by_name" do
      it "searches tenants by name" do
        expect(Tenant.search_by_name("Alpha")).to include(tenant1)
        expect(Tenant.search_by_name("Alpha")).not_to include(tenant2, tenant3, tenant4)
      end

      it "returns all tenants when query is blank" do
        expect(Tenant.search_by_name("")).to include(tenant1, tenant2, tenant3, tenant4)
      end

      it "is case insensitive" do
        expect(Tenant.search_by_name("alpha")).to include(tenant1)
      end
    end
  end

  describe "callbacks" do
    describe "set_default_domain" do
      it "sets domain based on name if not provided" do
        tenant = build(:tenant, name: "TestTenant", domain: nil)
        tenant.valid?
        expect(tenant.domain).to eq("testtenant.aurid.io")
      end

      it "does not override existing domain" do
        tenant = build(:tenant, name: "TestTenant", domain: "custom.com")
        tenant.valid?
        expect(tenant.domain).to eq("custom.com")
      end
    end

    describe "generate_api_key" do
      it "generates API key on creation" do
        tenant = create(:tenant)
        expect(tenant.api_key).to be_present
        expect(tenant.api_key.length).to be >= 64
      end

      it "generates API key digest" do
        tenant = create(:tenant)
        expect(tenant.api_key_digest).to be_present
        expect(tenant.api_key_digest).to eq(Digest::SHA256.hexdigest(tenant.api_key))
      end
    end
  end

  describe "methods" do
    let(:tenant) { create(:tenant, max_users: 100) }

    describe "display_name" do
      it "returns the name" do
        expect(tenant.display_name).to eq(tenant.name)
      end
    end

    describe "user_count" do
      it "returns the number of users" do
        create_list(:user, 3, tenant: tenant)
        expect(tenant.user_count).to eq(3)
      end
    end

    describe "active_user_count" do
      it "returns the number of active users" do
        create(:user, :active, tenant: tenant)
        create(:user, :active, tenant: tenant)
        create(:user, :suspended, tenant: tenant)
        expect(tenant.active_user_count).to eq(2)
      end
    end

    describe "can_add_users?" do
      it "returns true when under max_users limit" do
        create_list(:user, 5, tenant: tenant)
        expect(tenant.can_add_users?).to be true
      end

      it "returns false when at max_users limit" do
        create_list(:user, 100, tenant: tenant)
        expect(tenant.can_add_users?).to be false
      end

      it "returns true when max_users is nil (unlimited)" do
        tenant.update(max_users: nil)
        create_list(:user, 1000, tenant: tenant)
        expect(tenant.can_add_users?).to be true
      end
    end

    describe "users_remaining" do
      it "returns remaining user slots" do
        create_list(:user, 5, tenant: tenant)
        expect(tenant.users_remaining).to eq(95)
      end

      it "returns infinity when max_users is nil" do
        tenant.update(max_users: nil)
        expect(tenant.users_remaining).to eq(Float::INFINITY)
      end
    end

    describe "billing_enabled?" do
      it "returns false for free tier" do
        tenant.update(tier: :free)
        expect(tenant.billing_enabled?).to be false
      end

      it "returns true for other tiers" do
        %i[basic professional enterprise].each do |tier|
          tenant.update(tier: tier)
          expect(tenant.billing_enabled?).to be true
        end
      end
    end

    describe "audit_logging_enabled?" do
      it "returns true by default" do
        expect(tenant.audit_logging_enabled?).to be true
      end

      it "returns value from settings if present" do
        create(:tenant_setting, tenant: tenant, key: "audit_logging_enabled", value: "false")
        expect(tenant.audit_logging_enabled?).to be false
      end
    end

    describe "ad_migration_enabled?" do
      it "returns true for professional and enterprise tiers" do
        %i[professional enterprise].each do |tier|
          tenant.update(tier: tier)
          expect(tenant.ad_migration_enabled?).to be true
        end
      end

      it "returns value from settings if present" do
        tenant.update(tier: :basic)
        create(:tenant_setting, tenant: tenant, key: "ad_migration_enabled", value: "true")
        expect(tenant.ad_migration_enabled?).to be true
      end
    end

    describe "generate_new_api_key" do
      it "generates a new API key" do
        old_key = tenant.api_key
        new_key = tenant.generate_new_api_key
        expect(new_key).not_to eq(old_key)
        expect(new_key.length).to be >= 64
      end

      it "updates the api_key attribute" do
        old_key = tenant.api_key
        tenant.generate_new_api_key
        tenant.reload
        expect(tenant.api_key).not_to eq(old_key)
      end
    end

    describe "api_key_digest" do
      it "returns SHA256 digest of api_key" do
        expect(tenant.api_key_digest).to eq(Digest::SHA256.hexdigest(tenant.api_key))
      end

      it "returns nil when api_key is blank" do
        tenant.update(api_key: nil)
        expect(tenant.api_key_digest).to be_nil
      end
    end
  end

  describe "class methods" do
    describe ".default" do
      it "creates or finds the default tenant" do
        default = Tenant.default
        expect(default.name).to eq("Default")
        expect(default.domain).to eq("aurid.io")
        expect(default.status).to eq("active")
        expect(default.tier).to eq("enterprise")
      end

      it "returns the same tenant on subsequent calls" do
        default1 = Tenant.default
        default2 = Tenant.default
        expect(default1).to eq(default2)
      end
    end

    describe ".current" do
      it "returns the current tenant from Current" do
        tenant = create(:tenant)
        Tenant.current = tenant
        expect(Tenant.current).to eq(tenant)
      end

      it "returns default tenant when Current.tenant is nil" do
        Tenant.current = nil
        expect(Tenant.current).to eq(Tenant.default)
      end
    end

    describe ".current=" do
      it "sets the current tenant" do
        tenant = create(:tenant)
        Tenant.current = tenant
        expect(Current.tenant).to eq(tenant)
      end
    end
  end

  describe "soft deletion" do
    let(:tenant) { create(:tenant) }

    it "is active by default" do
      expect(tenant).to be_active
      expect(tenant).not_to be_deleted
    end

    describe "soft_delete" do
      it "sets deleted_at timestamp" do
        tenant.soft_delete
        expect(tenant.deleted_at).to be_present
      end

      it "makes tenant deleted" do
        tenant.soft_delete
        expect(tenant).to be_deleted
        expect(tenant).not_to be_active
      end
    end

    describe "restore" do
      it "clears deleted_at timestamp" do
        tenant.soft_delete
        tenant.restore
        expect(tenant.deleted_at).to be_nil
      end

      it "makes tenant active again" do
        tenant.soft_delete
        tenant.restore
        expect(tenant).to be_active
        expect(tenant).not_to be_deleted
      end
    end

    describe "scopes" do
      let!(:active_tenant) { create(:tenant) }
      let!(:deleted_tenant) { create(:tenant) }

      before do
        deleted_tenant.soft_delete
      end

      it "actives scope excludes deleted tenants" do
        expect(Tenant.actives).to include(active_tenant)
        expect(Tenant.actives).not_to include(deleted_tenant)
      end

      it "deleted scope includes only deleted tenants" do
        expect(Tenant.deleted).to include(deleted_tenant)
        expect(Tenant.deleted).not_to include(active_tenant)
      end
    end
  end

  describe "metadata and custom_branding" do
    it "has metadata as jsonb" do
      tenant = create(:tenant, metadata: { custom_field: "value" })
      expect(tenant.metadata["custom_field"]).to eq("value")
    end

    it "has custom_branding as jsonb" do
      tenant = create(:tenant, custom_branding: { logo: "logo.png", colors: { primary: "#000" } })
      expect(tenant.custom_branding["logo"]).to eq("logo.png")
      expect(tenant.custom_branding["colors"]["primary"]).to eq("#000")
    end

    it "has default empty hashes" do
      tenant = create(:tenant)
      expect(tenant.metadata).to eq({})
      expect(tenant.custom_branding).to eq({})
    end
  end
end
