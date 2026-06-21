# User Model Tests

require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_length_of(:first_name).is_at_most(100) }
    it { should validate_length_of(:last_name).is_at_most(100) }
    
    it { should allow_value("test@example.com").for(:email) }
    it { should allow_value("user+tag@example.co.uk").for(:email) }
    it { should_not allow_value("invalid-email").for(:email) }
    it { should_not allow_value("@example.com").for(:email) }
    it { should_not allow_value("user@.com").for(:email) }
    
    it { should allow_value("pending").for(:status) }
    it { should allow_value("active").for(:status) }
    it { should allow_value("suspended").for(:status) }
    it { should allow_value("disabled").for(:status) }
    it { should_not allow_value("invalid").for(:status) }
    
    describe "password validation" do
      it { should validate_length_of(:password).is_at_least(12).allow_nil }
      
      it "requires password on creation" do
        user = build(:user, password: nil, password_confirmation: nil)
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include("can't be blank")
      end
      
      it "does not require password on update" do
        user = create(:user)
        user.password = nil
        user.password_confirmation = nil
        expect(user).to be_valid
      end
      
      it "requires password confirmation" do
        user = build(:user, password_confirmation: nil)
        expect(user).not_to be_valid
        expect(user.errors[:password_confirmation]).to include("doesn't match Password")
      end
      
      it "validates password confirmation matches" do
        user = build(:user, password: "Password123!", password_confirmation: "Different123!")
        expect(user).not_to be_valid
        expect(user.errors[:password_confirmation]).to include("doesn't match Password")
      end
    end
  end

  describe "associations" do
    it { should belong_to(:tenant).optional }
    it { should have_many(:sessions).dependent(:destroy) }
    it { should have_many(:audit_logs).dependent(:nullify) }
    it { should have_many(:user_roles).dependent(:destroy) }
    it { should have_many(:roles).through(:user_roles) }
    it { should have_many(:mfa_devices).dependent(:destroy) }
    it { should have_many(:notifications).dependent(:destroy) }
    it { should have_many(:api_tokens).dependent(:destroy) }
  end

  describe "scopes" do
    let!(:active_user) { create(:user, :active) }
    let!(:pending_user) { create(:user, :pending) }
    let!(:suspended_user) { create(:user, :suspended) }
    let!(:disabled_user) { create(:user, :disabled) }
    let!(:tenant1) { create(:tenant) }
    let!(:tenant2) { create(:tenant) }
    let!(:user1) { create(:user, tenant: tenant1) }
    let!(:user2) { create(:user, tenant: tenant2) }

    describe ".active" do
      it "returns only active users" do
        expect(User.active).to include(active_user)
        expect(User.active).not_to include(pending_user, suspended_user, disabled_user)
      end
    end

    describe ".admins" do
      it "returns users with admin role" do
        admin = create(:user, :admin)
        expect(User.admins).to include(admin)
      end
    end

    describe ".by_tenant" do
      it "filters users by tenant" do
        expect(User.by_tenant(tenant1)).to include(user1)
        expect(User.by_tenant(tenant1)).not_to include(user2)
      end
    end

    describe ".ordered_by_name" do
      it "orders users by first and last name" do
        create(:user, first_name: "Zoe", last_name: "Zander")
        create(:user, first_name: "Alice", last_name: "Adams")
        create(:user, first_name: "Bob", last_name: "Baker")
        
        names = User.ordered_by_name.pluck(:first_name)
        expect(names).to eq(["Alice", "Bob", "Zoe"])
      end
    end

    describe ".search_by_email" do
      it "searches users by email" do
        user = create(:user, email: "search@example.com")
        expect(User.search_by_email("search")).to include(user)
        expect(User.search_by_email("other")).not_to include(user)
      end

      it "returns all users when query is blank" do
        expect(User.search_by_email("")).to include(active_user, pending_user)
      end
    end

    describe ".search_by_name" do
      it "searches users by first or last name" do
        user = create(:user, first_name: "John", last_name: "Doe")
        expect(User.search_by_name("John")).to include(user)
        expect(User.search_by_name("Doe")).to include(user)
        expect(User.search_by_name("Jane")).not_to include(user)
      end
    end
  end

  describe "callbacks" do
    describe "set_tenant" do
      it "sets default tenant if not provided" do
        user = build(:user, tenant: nil)
        user.valid?
        expect(user.tenant).to eq(Tenant.default)
      end

      it "does not override existing tenant" do
        tenant = create(:tenant)
        user = build(:user, tenant: tenant)
        user.valid?
        expect(user.tenant).to eq(tenant)
      end
    end

    describe "assign_default_role" do
      it "assigns viewer role by default" do
        user = create(:user)
        expect(user.roles.pluck(:name)).to include("viewer")
      end

      it "makes first user of tenant an admin" do
        tenant = create(:tenant)
        user = create(:user, tenant: tenant)
        expect(user.roles.pluck(:name)).to include("admin", "viewer")
      end

      it "does not make subsequent users admins" do
        tenant = create(:tenant)
        create(:user, tenant: tenant) # First user (admin)
        user2 = create(:user, tenant: tenant) # Second user
        expect(user2.roles.pluck(:name)).to include("viewer")
        expect(user2.roles.pluck(:name)).not_to include("admin")
      end
    end
  end

  describe "methods" do
    let(:user) { create(:user, first_name: "John", last_name: "Doe") }

    describe "full_name" do
      it "returns first and last name joined" do
        expect(user.full_name).to eq("John Doe")
      end

      it "handles nil names" do
        user.update(first_name: nil, last_name: "Doe")
        expect(user.full_name).to eq(" Doe")
      end
    end

    describe "display_name" do
      it "returns full_name when present" do
        expect(user.display_name).to eq("John Doe")
      end

      it "returns email when name is blank" do
        user.update(first_name: nil, last_name: nil)
        expect(user.display_name).to eq(user.email)
      end
    end

    describe "role checks" do
      it "admin? returns true for admin users" do
        admin = create(:user, :admin)
        expect(admin).to be_admin
        expect(admin.admin?).to be true
      end

      it "admin? returns false for non-admin users" do
        expect(user).not_to be_admin
        expect(user.admin?).to be false
      end

      it "super_admin? returns true for super admin users" do
        super_admin = create(:user, :super_admin)
        expect(super_admin).to be_super_admin
        expect(super_admin.super_admin?).to be true
      end

      it "tenant_admin? returns true for tenant admins" do
        admin = create(:user, :admin)
        expect(admin).to be_tenant_admin
      end

      it "can_manage_tenant? returns true for super admins" do
        super_admin = create(:user, :super_admin)
        tenant = create(:tenant)
        expect(super_admin.can_manage_tenant?(tenant)).to be true
      end

      it "can_manage_tenant? returns true for tenant admins of same tenant" do
        tenant = create(:tenant)
        admin = create(:user, :admin, tenant: tenant)
        expect(admin.can_manage_tenant?(tenant)).to be true
      end

      it "can_manage_tenant? returns false for tenant admins of different tenant" do
        tenant1 = create(:tenant)
        tenant2 = create(:tenant)
        admin = create(:user, :admin, tenant: tenant1)
        expect(admin.can_manage_tenant?(tenant2)).to be false
      end

      it "can_manage_users? returns true for admins" do
        admin = create(:user, :admin)
        expect(admin.can_manage_users?).to be true
      end

      it "can_manage_settings? returns true for admins" do
        admin = create(:user, :admin)
        expect(admin.can_manage_settings?).to be true
      end

      it "can_run_migrations? returns true for super admins" do
        super_admin = create(:user, :super_admin)
        expect(super_admin.can_run_migrations?).to be true
      end

      it "can_run_migrations? returns true for migration admins" do
        user = create(:user)
        migration_admin_role = create(:role, name: "migration_admin")
        create(:user_role, user: user, role: migration_admin_role)
        expect(user.can_run_migrations?).to be true
      end
    end

    describe "MFA methods" do
      it "mfa_enabled? returns false when no MFA devices" do
        expect(user.mfa_enabled?).to be false
      end

      it "mfa_enabled? returns true when MFA device is enabled" do
        create(:mfa_device, user: user, enabled: true)
        expect(user.mfa_enabled?).to be true
      end

      it "mfa_required? returns false by default" do
        expect(user.mfa_required?).to be false
      end

      it "mfa_required? returns true for super admins" do
        super_admin = create(:user, :super_admin)
        expect(super_admin.mfa_required?).to be true
      end
    end

    describe "session methods" do
      it "last_active_at returns latest session time" do
        create(:session, user: user, created_at: 1.hour.ago)
        create(:session, user: user, created_at: 30.minutes.ago)
        expect(user.last_active_at).to be_within(1.minute).of(30.minutes.ago)
      end

      it "last_active_at returns updated_at when no sessions" do
        expect(user.last_active_at).to eq(user.updated_at)
      end

      it "active_sessions_count returns count of active sessions" do
        create(:session, :active, user: user)
        create(:session, :active, user: user)
        create(:session, :revoked, user: user)
        expect(user.active_sessions_count).to eq(2)
      end

      it "deactivate_all_sessions! revokes all sessions" do
        create(:session, :active, user: user)
        create(:session, :active, user: user)
        user.deactivate_all_sessions!
        expect(user.sessions.reload.pluck(:status)).to all(eq("revoked"))
      end
    end

    describe "API token methods" do
      it "generate_api_token creates a new token" do
        token = user.generate_api_token("Test Token")
        expect(token).to be_present
        expect(token.name).to eq("Test Token")
        expect(token.user).to eq(user)
      end

      it "adds token to user's api_tokens" do
        expect { user.generate_api_token }.to change { user.api_tokens.count }.by(1)
      end
    end

    describe "jwt_payload" do
      it "returns proper JWT payload" do
        payload = user.jwt_payload
        expect(payload[:sub]).to eq(user.id)
        expect(payload[:email]).to eq(user.email)
        expect(payload[:tenant_id]).to eq(user.tenant_id)
        expect(payload[:roles]).to eq(user.roles.pluck(:name))
        expect(payload[:jti]).to be_present
        expect(payload[:iat]).to be_present
      end
    end
  end

  describe "class methods" do
    describe ".current" do
      it "returns the current user from Current" do
        user = create(:user)
        User.current = user
        expect(User.current).to eq(user)
      end

      it "returns nil when Current.user is nil" do
        User.current = nil
        expect(User.current).to be_nil
      end
    end

    describe ".current=" do
      it "sets the current user" do
        user = create(:user)
        User.current = user
        expect(Current.user).to eq(user)
      end
    end

    describe ".super_admins" do
      it "returns users with super_admin role" do
        super_admin = create(:user, :super_admin)
        create(:user, :admin)
        create(:user)
        
        expect(User.super_admins).to include(super_admin)
        expect(User.super_admins.count).to eq(1)
      end
    end
  end

  describe "soft deletion" do
    let(:user) { create(:user) }

    it "is active by default" do
      expect(user).to be_active
      expect(user).not_to be_deleted
    end

    describe "soft_delete" do
      it "sets deleted_at timestamp" do
        user.soft_delete
        expect(user.deleted_at).to be_present
      end

      it "makes user deleted" do
        user.soft_delete
        expect(user).to be_deleted
        expect(user).not_to be_active
      end
    end

    describe "restore" do
      it "clears deleted_at timestamp" do
        user.soft_delete
        user.restore
        expect(user.deleted_at).to be_nil
      end

      it "makes user active again" do
        user.soft_delete
        user.restore
        expect(user).to be_active
        expect(user).not_to be_deleted
      end
    end

    describe "scopes" do
      let!(:active_user) { create(:user) }
      let!(:deleted_user) { create(:user) }

      before do
        deleted_user.soft_delete
      end

      it "actives scope excludes deleted users" do
        expect(User.actives).to include(active_user)
        expect(User.actives).not_to include(deleted_user)
      end

      it "deleted scope includes only deleted users" do
        expect(User.deleted).to include(deleted_user)
        expect(User.deleted).not_to include(active_user)
      end
    end
  end

  describe "metadata and preferences" do
    it "has metadata as jsonb" do
      user = create(:user, metadata: { department: "Engineering", level: "Senior" })
      expect(user.metadata["department"]).to eq("Engineering")
      expect(user.metadata["level"]).to eq("Senior")
    end

    it "has preferences as jsonb" do
      user = create(:user, preferences: { theme: "dark", notifications: true })
      expect(user.preferences["theme"]).to eq("dark")
      expect(user.preferences["notifications"]).to be true
    end

    it "has default empty hashes" do
      user = create(:user)
      expect(user.metadata).to eq({})
      expect(user.preferences).to eq({})
    end
  end

  describe "Devise integration" do
    it "has database_authenticatable" do
      expect(User.ancestors).to include(Devise::Models::DatabaseAuthenticatable)
    end

    it "has registerable" do
      expect(User.ancestors).to include(Devise::Models::Registerable)
    end

    it "has recoverable" do
      expect(User.ancestors).to include(Devise::Models::Recoverable)
    end

    it "has rememberable" do
      expect(User.ancestors).to include(Devise::Models::Rememberable)
    end

    it "has validatable" do
      expect(User.ancestors).to include(Devise::Models::Validatable)
    end

    it "has jwt_authenticatable" do
      expect(User.ancestors).to include(Devise::Models::JwtAuthenticatable)
    end
  end
end
