# API v1 Tenants Controller Tests

require "rails_helper"

RSpec.describe Api::V1::TenantsController, type: :controller do
  let(:super_admin) { create(:user, :super_admin) }
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:tenant) { create(:tenant) }
  let(:other_tenant) { create(:tenant) }

  # Helper to set auth headers
  def set_auth_headers(user)
    token = generate_jwt_token(user)
    request.headers["Authorization"] = "Bearer #{token}"
  end

  # Helper to generate JWT token
  def generate_jwt_token(user)
    payload = user.jwt_payload
    payload[:exp] = 1.hour.from_now.to_i
    JWT.encode(payload, Devise.jwt.secret, Devise.jwt.signing_algorithm)
  end

  describe "GET #index" do
    context "with super admin" do
      before { set_auth_headers(super_admin) }

      it "returns list of tenants" do
        create_list(:tenant, 3)
        
        get :index
        
        expect(response).to have_http_status(:success)
        expect(json_response[:success]).to be true
        expect(json_response[:data]).to be_an(Array)
        expect(json_response[:data].size).to eq(4) # 3 created + 1 default
      end

      it "returns pagination meta" do
        create_list(:tenant, 30)
        
        get :index
        
        expect(json_response[:meta]).to be_present
        expect(json_response[:meta][:current_page]).to eq(1)
        expect(json_response[:meta][:per_page]).to eq(25)
        expect(json_response[:meta][:total_count]).to be >= 30
      end

      it "filters by status" do
        create(:tenant, status: :pending)
        create(:tenant, status: :suspended)
        
        get :index, params: { status: :active }
        
        expect(json_response[:data].size).to be >= 1
        expect(json_response[:data].all? { |t| t[:status] == "active" }).to be true
      end

      it "filters by name" do
        create(:tenant, name: "TestTenant")
        
        get :index, params: { name: "Test" }
        
        expect(json_response[:data].any? { |t| t[:name] == "TestTenant" }).to be true
      end

      it "orders by name" do
        create(:tenant, name: "Zebra")
        create(:tenant, name: "Alpha")
        
        get :index
        
        names = json_response[:data].map { |t| t[:name] }
        expect(names).to be_sorted
      end
    end

    context "with regular admin" do
      before { set_auth_headers(admin) }

      it "returns unauthorized" do
        get :index
        
        expect(response).to have_http_status(:forbidden)
        expect(json_response[:error]).to eq("forbidden")
      end
    end

    context "with regular user" do
      before { set_auth_headers(regular_user) }

      it "returns unauthorized" do
        get :index
        
        expect(response).to have_http_status(:forbidden)
        expect(json_response[:error]).to eq("forbidden")
      end
    end

    context "without authentication" do
      it "returns unauthorized" do
        get :index
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET #show" do
    context "with super admin" do
      before { set_auth_headers(super_admin) }

      it "returns tenant details" do
        get :show, params: { id: tenant.id }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:success]).to be true
        expect(json_response[:data][:id]).to eq(tenant.id.to_s)
        expect(json_response[:data][:name]).to eq(tenant.name)
        expect(json_response[:data][:domain]).to eq(tenant.domain)
      end

      it "returns tenant statistics" do
        create_list(:user, 3, tenant: tenant)
        
        get :show, params: { id: tenant.id }
        
        expect(json_response[:data][:user_count]).to eq(3)
        expect(json_response[:data][:active_user_count]).to eq(3)
      end

      it "returns billing info" do
        tenant.update(billing_email: "billing@test.com")
        
        get :show, params: { id: tenant.id }
        
        expect(json_response[:data][:billing_info][:email]).to eq("billing@test.com")
      end
    end

    context "with tenant admin" do
      before do
        admin.update(tenant: tenant)
        set_auth_headers(admin)
      end

      it "returns tenant details" do
        get :show, params: { id: tenant.id }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:data][:id]).to eq(tenant.id.to_s)
      end
    end

    context "with user from different tenant" do
      before do
        regular_user.update(tenant: other_tenant)
        set_auth_headers(regular_user)
      end

      it "returns forbidden" do
        get :show, params: { id: tenant.id }
        
        expect(response).to have_http_status(:forbidden)
        expect(json_response[:error]).to eq("forbidden")
      end
    end

    context "with non-existent tenant" do
      before { set_auth_headers(super_admin) }

      it "returns not found" do
        get :show, params: { id: SecureRandom.uuid }
        
        expect(response).to have_http_status(:not_found)
        expect(json_response[:error]).to eq("not_found")
      end
    end
  end

  describe "POST #create" do
    context "with super admin" do
      before { set_auth_headers(super_admin) }

      it "creates a new tenant" do
        tenant_params = {
          tenant: {
            name: "NewTenant",
            domain: "newtenant.aurid.io",
            description: "A new tenant",
            tier: "basic",
            max_users: 100
          }
        }
        
        expect {
          post :create, params: tenant_params
        }.to change(Tenant, :count).by(1)
        
        expect(response).to have_http_status(:created)
        expect(json_response[:success]).to be true
        expect(json_response[:data][:name]).to eq("NewTenant")
        expect(json_response[:message]).to eq("Tenant created successfully")
      end

      it "returns validation errors" do
        tenant_params = {
          tenant: {
            name: "", # Invalid: name is required
            domain: "newtenant.aurid.io"
          }
        }
        
        post :create, params: tenant_params
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:success]).to be false
        expect(json_response[:error]).to eq("validation_failed")
        expect(json_response[:details]).to include("Name can't be blank")
      end

      it "sets default values" do
        tenant_params = {
          tenant: {
            name: "MinimalTenant",
            domain: "minimal.aurid.io"
          }
        }
        
        post :create, params: tenant_params
        
        expect(json_response[:data][:status]).to eq("pending")
        expect(json_response[:data][:tier]).to eq("free")
      end
    end

    context "with regular admin" do
      before { set_auth_headers(admin) }

      it "returns unauthorized" do
        post :create, params: { tenant: { name: "Test" } }
        
        expect(response).to have_http_status(:forbidden)
        expect(json_response[:error]).to eq("forbidden")
      end
    end
  end

  describe "PATCH #update" do
    context "with super admin" do
      before { set_auth_headers(super_admin) }

      it "updates tenant" do
        patch :update, params: {
          id: tenant.id,
          tenant: {
            name: "UpdatedTenant",
            description: "Updated description"
          }
        }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:success]).to be true
        expect(json_response[:data][:name]).to eq("UpdatedTenant")
        expect(json_response[:message]).to eq("Tenant updated successfully")
      end

      it "returns validation errors" do
        patch :update, params: {
          id: tenant.id,
          tenant: {
            domain: "" # Invalid: domain is required
          }
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error]).to eq("validation_failed")
      end
    end

    context "with tenant admin" do
      before do
        admin.update(tenant: tenant)
        set_auth_headers(admin)
      end

      it "updates tenant" do
        patch :update, params: {
          id: tenant.id,
          tenant: {
            description: "Updated by admin"
          }
        }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:data][:description]).to eq("Updated by admin")
      end
    end

    context "with user from different tenant" do
      before do
        regular_user.update(tenant: other_tenant)
        set_auth_headers(regular_user)
      end

      it "returns forbidden" do
        patch :update, params: {
          id: tenant.id,
          tenant: { description: "Should not update" }
        }
        
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "DELETE #destroy" do
    context "with super admin" do
      before { set_auth_headers(super_admin) }

      it "soft deletes tenant" do
        delete :destroy, params: { id: tenant.id }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:success]).to be true
        expect(json_response[:message]).to eq("Tenant deleted successfully")
        
        # Verify tenant is soft deleted
        tenant.reload
        expect(tenant).to be_deleted
      end

      it "returns not found for non-existent tenant" do
        delete :destroy, params: { id: SecureRandom.uuid }
        
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with regular admin" do
      before { set_auth_headers(admin) }

      it "returns unauthorized" do
        delete :destroy, params: { id: tenant.id }
        
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "POST #restore" do
    let(:deleted_tenant) { create(:tenant) }

    before do
      deleted_tenant.soft_delete
    end

    context "with super admin" do
      before { set_auth_headers(super_admin) }

      it "restores deleted tenant" do
        post :restore, params: { id: deleted_tenant.id }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:success]).to be true
        expect(json_response[:message]).to eq("Tenant restored successfully")
        
        # Verify tenant is restored
        deleted_tenant.reload
        expect(deleted_tenant).to be_active
      end

      it "returns not found for non-existent tenant" do
        post :restore, params: { id: SecureRandom.uuid }
        
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with regular admin" do
      before { set_auth_headers(admin) }

      it "returns unauthorized" do
        post :restore, params: { id: deleted_tenant.id }
        
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET #users" do
    context "with super admin" do
      before { set_auth_headers(super_admin) }

      it "returns list of users in tenant" do
        create_list(:user, 3, tenant: tenant)
        
        get :users, params: { id: tenant.id }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:success]).to be true
        expect(json_response[:data].size).to eq(3)
      end

      it "filters by status" do
        create(:user, :active, tenant: tenant)
        create(:user, :suspended, tenant: tenant)
        
        get :users, params: { id: tenant.id, status: "active" }
        
        expect(json_response[:data].size).to eq(1)
        expect(json_response[:data].first[:status]).to eq("active")
      end

      it "filters by email" do
        create(:user, email: "search@example.com", tenant: tenant)
        create(:user, email: "other@example.com", tenant: tenant)
        
        get :users, params: { id: tenant.id, email: "search" }
        
        expect(json_response[:data].size).to eq(1)
        expect(json_response[:data].first[:email]).to eq("search@example.com")
      end

      it "filters by name" do
        create(:user, first_name: "John", tenant: tenant)
        create(:user, first_name: "Jane", tenant: tenant)
        
        get :users, params: { id: tenant.id, name: "John" }
        
        expect(json_response[:data].size).to eq(1)
        expect(json_response[:data].first[:first_name]).to eq("John")
      end

      it "paginates results" do
        create_list(:user, 30, tenant: tenant)
        
        get :users, params: { id: tenant.id, per_page: 10 }
        
        expect(json_response[:data].size).to eq(10)
        expect(json_response[:meta][:total_count]).to eq(30)
        expect(json_response[:meta][:total_pages]).to eq(3)
      end
    end

    context "with tenant admin" do
      before do
        admin.update(tenant: tenant)
        set_auth_headers(admin)
      end

      it "returns users in tenant" do
        create_list(:user, 3, tenant: tenant)
        
        get :users, params: { id: tenant.id }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:data].size).to eq(3)
      end
    end

    context "with user from different tenant" do
      before do
        regular_user.update(tenant: other_tenant)
        set_auth_headers(regular_user)
      end

      it "returns forbidden" do
        get :users, params: { id: tenant.id }
        
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET #settings" do
    context "with super admin" do
      before { set_auth_headers(super_admin) }

      it "returns tenant settings" do
        create(:tenant_setting, tenant: tenant, key: "audit_logging_enabled", value: "true")
        create(:tenant_setting, tenant: tenant, key: "ad_migration_enabled", value: "true")
        
        get :settings, params: { id: tenant.id }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:success]).to be true
        expect(json_response[:data].size).to eq(2)
        expect(json_response[:data].first[:key]).to eq("audit_logging_enabled")
      end
    end

    context "with tenant admin" do
      before do
        admin.update(tenant: tenant)
        set_auth_headers(admin)
      end

      it "returns tenant settings" do
        create(:tenant_setting, tenant: tenant, key: "test_setting", value: "test_value")
        
        get :settings, params: { id: tenant.id }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:data].size).to be >= 1
      end
    end
  end

  describe "POST #regenerate_api_key" do
    context "with super admin" do
      before { set_auth_headers(super_admin) }

      it "regenerates API key" do
        old_key = tenant.api_key
        
        post :regenerate_api_key, params: { id: tenant.id }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:success]).to be true
        expect(json_response[:data][:api_key]).to be_present
        expect(json_response[:data][:api_key]).not_to eq(old_key)
        expect(json_response[:message]).to eq("API key regenerated successfully")
        
        # Verify the key was actually regenerated
        tenant.reload
        expect(tenant.api_key).not_to eq(old_key)
      end
    end

    context "with regular admin" do
      before { set_auth_headers(admin) }

      it "returns unauthorized" do
        post :regenerate_api_key, params: { id: tenant.id }
        
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # Test tenant serializer
  describe "tenant serialization" do
    before { set_auth_headers(super_admin) }

    it "includes all expected fields" do
      get :show, params: { id: tenant.id }
      
      tenant_data = json_response[:data]
      
      expect(tenant_data).to have_key(:id)
      expect(tenant_data).to have_key(:name)
      expect(tenant_data).to have_key(:domain)
      expect(tenant_data).to have_key(:description)
      expect(tenant_data).to have_key(:status)
      expect(tenant_data).to have_key(:tier)
      expect(tenant_data).to have_key(:max_users)
      expect(tenant_data).to have_key(:user_count)
      expect(tenant_data).to have_key(:active_user_count)
      expect(tenant_data).to have_key(:can_add_users)
      expect(tenant_data).to have_key(:billing_enabled)
      expect(tenant_data).to have_key(:audit_logging_enabled)
      expect(tenant_data).to have_key(:ad_migration_enabled)
      expect(tenant_data).to have_key(:billing_info)
      expect(tenant_data).to have_key(:created_at)
      expect(tenant_data).to have_key(:updated_at)
    end
  end

  # Test user serialization in tenant context
  describe "user serialization" do
    before do
      create_list(:user, 3, tenant: tenant)
      set_auth_headers(super_admin)
    end

    it "includes all expected user fields" do
      get :users, params: { id: tenant.id }
      
      user_data = json_response[:data].first
      
      expect(user_data).to have_key(:id)
      expect(user_data).to have_key(:email)
      expect(user_data).to have_key(:first_name)
      expect(user_data).to have_key(:last_name)
      expect(user_data).to have_key(:full_name)
      expect(user_data).to have_key(:display_name)
      expect(user_data).to have_key(:status)
      expect(user_data).to have_key(:roles)
      expect(user_data).to have_key(:mfa_enabled)
      expect(user_data).to have_key(:mfa_required)
      expect(user_data).to have_key(:created_at)
      expect(user_data).to have_key(:updated_at)
    end
  end
end
