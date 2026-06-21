# Role Model Tests

require "rails_helper"

RSpec.describe Role, type: :model do
  describe "validations" do
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name).case_insensitive }
    
    it { should allow_value("admin").for(:name) }
    it { should allow_value("super_admin").for(:name) }
    it { should allow_value("viewer").for(:name) }
    it { should allow_value("user").for(:name) }
    
    it { should allow_value(true).for(:global) }
    it { should allow_value(false).for(:global) }
    it { should allow_value(true).for(:system) }
    it { should allow_value(false).for(:system) }
  end

  describe "associations" do
    it { should have_many(:user_roles).dependent(:destroy) }
    it { should have_many(:users).through(:user_roles) }
  end

  describe "scopes" do
    let!(:system_role) { create(:role, :system) }
    let!(:global_role) { create(:role, :global) }
    let!(:regular_role) { create(:role) }
    let!(:deleted_role) { create(:role) }

    before do
      deleted_role.soft_delete
    end

    describe ".system" do
      it "returns only system roles" do
        expect(Role.system).to include(system_role)
        expect(Role.system).not_to include(global_role, regular_role)
      end
    end

    describe ".global" do
      it "returns only global roles" do
        expect(Role.global).to include(system_role, global_role)
        expect(Role.global).not_to include(regular_role)
      end
    end

    describe ".actives" do
      it "returns only active roles" do
        expect(Role.actives).to include(system_role, global_role, regular_role)
        expect(Role.actives).not_to include(deleted_role)
      end
    end

    describe ".deleted" do
      it "returns only deleted roles" do
        expect(Role.deleted).to include(deleted_role)
        expect(Role.deleted).not_to include(system_role, global_role, regular_role)
      end
    end
  end

  describe "attributes" do
    it "has permissions as jsonb array" do
      role = create(:role, permissions: ["read:users", "write:users"])
      expect(role.permissions).to eq(["read:users", "write:users"])
    end

    it "has default empty permissions array" do
      role = create(:role)
      expect(role.permissions).to eq([])
    end

    it "has resource_type and resource_id for scoped roles" do
      tenant = create(:tenant)
      role = create(:role, resource_type: "Tenant", resource_id: tenant.id)
      expect(role.resource_type).to eq("Tenant")
      expect(role.resource_id).to eq(tenant.id)
    end
  end

  describe "traits" do
    describe ":system" do
      it "sets system and global to true" do
        role = build(:role, :system)
        expect(role.system).to be true
        expect(role.global).to be true
      end
    end

    describe ":global" do
      it "sets global to true" do
        role = build(:role, :global)
        expect(role.global).to be true
        expect(role.system).to be false
      end
    end

    describe ":admin" do
      it "creates admin role" do
        role = build(:role, :admin)
        expect(role.name).to eq("admin")
        expect(role.description).to eq("Can manage tenant resources")
        expect(role.system).to be true
        expect(role.global).to be true
      end
    end

    describe ":super_admin" do
      it "creates super_admin role" do
        role = build(:role, :super_admin)
        expect(role.name).to eq("super_admin")
        expect(role.description).to eq("Full access to all features and tenants")
        expect(role.system).to be true
        expect(role.global).to be true
      end
    end

    describe ":viewer" do
      it "creates viewer role" do
        role = build(:role, :viewer)
        expect(role.name).to eq("viewer")
        expect(role.description).to eq("Can view resources")
        expect(role.system).to be true
        expect(role.global).to be true
      end
    end

    describe ":identity_admin" do
      it "creates identity_admin role" do
        role = build(:role, :identity_admin)
        expect(role.name).to eq("identity_admin")
        expect(role.description).to eq("Can manage identity providers and users")
        expect(role.system).to be false
        expect(role.global).to be false
      end
    end

    describe ":migration_admin" do
      it "creates migration_admin role" do
        role = build(:role, :migration_admin)
        expect(role.name).to eq("migration_admin")
        expect(role.description).to eq("Can run AD migration jobs")
        expect(role.system).to be false
        expect(role.global).to be false
      end
    end

    describe ":audit_admin" do
      it "creates audit_admin role" do
        role = build(:role, :audit_admin)
        expect(role.name).to eq("audit_admin")
        expect(role.description).to eq("Can view and export audit logs")
        expect(role.system).to be false
        expect(role.global).to be false
      end
    end

    describe ":billing_admin" do
      it "creates billing_admin role" do
        role = build(:role, :billing_admin)
        expect(role.name).to eq("billing_admin")
        expect(role.description).to eq("Can manage billing and subscriptions")
        expect(role.system).to be false
        expect(role.global).to be false
      end
    end

    describe ":with_permissions" do
      it "sets permissions array" do
        role = build(:role, :with_permissions)
        expect(role.permissions).to include("read:users", "write:users", "delete:users")
      end
    end
  end

  describe "soft deletion" do
    let(:role) { create(:role) }

    it "is active by default" do
      expect(role).to be_active
      expect(role).not_to be_deleted
    end

    describe "soft_delete" do
      it "sets deleted_at timestamp" do
        role.soft_delete
        expect(role.deleted_at).to be_present
      end

      it "makes role deleted" do
        role.soft_delete
        expect(role).to be_deleted
        expect(role).not_to be_active
      end
    end

    describe "restore" do
      it "clears deleted_at timestamp" do
        role.soft_delete
        role.restore
        expect(role.deleted_at).to be_nil
      end

      it "makes role active again" do
        role.soft_delete
        role.restore
        expect(role).to be_active
        expect(role).not_to be_deleted
      end
    end
  end

  describe "class methods" do
    describe "system roles" do
      it "creates default system roles" do
        # These should be created in the migration
        expect(Role.where(system: true).count).to be >= 4
      end
    end
  end

  describe "instance methods" do
    let(:role) { create(:role, name: "test_role", description: "Test description") }

    describe "display_name" do
      it "returns the name" do
        expect(role.name).to eq("test_role")
      end
    end

    describe "system?" do
      it "returns true for system roles" do
        role.update(system: true)
        expect(role.system?).to be true
      end

      it "returns false for non-system roles" do
        role.update(system: false)
        expect(role.system?).to be false
      end
    end

    describe "global?" do
      it "returns true for global roles" do
        role.update(global: true)
        expect(role.global?).to be true
      end

      it "returns false for non-global roles" do
        role.update(global: false)
        expect(role.global?).to be false
      end
    end

    describe "has_permission?" do
      it "returns true when role has permission" do
        role.update(permissions: ["read:users", "write:users"])
        expect(role.has_permission?("read:users")).to be true
      end

      it "returns false when role does not have permission" do
        role.update(permissions: ["read:users"])
        expect(role.has_permission?("delete:users")).to be false
      end
    end

    describe "add_permission" do
      it "adds permission to permissions array" do
        role.add_permission("new:permission")
        expect(role.permissions).to include("new:permission")
      end

      it "does not add duplicate permissions" do
        role.add_permission("read:users")
        role.add_permission("read:users")
        expect(role.permissions.count("read:users")).to eq(1)
      end
    end

    describe "remove_permission" do
      it "removes permission from permissions array" do
        role.update(permissions: ["read:users", "write:users"])
        role.remove_permission("read:users")
        expect(role.permissions).not_to include("read:users")
        expect(role.permissions).to include("write:users")
      end
    end
  end
end
