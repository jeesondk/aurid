# API v1 Users Controller Tests

require "rails_helper"

RSpec.describe Api::V1::UsersController, type: :controller do
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

      it "returns list of all users" do
        create_list(:user, 5)
        
        get :index
        
        expect(response).to have_http_status(:success)
        expect(json_response[:success]).to be true
        expect(json_response[:data]).to be_an(Array)
        expect(json_response[:data].size).to be >= 5
      end

      it "filters by tenant" do
        create_list(:user, 3, tenant: tenant)
        create_list(:user, 2, tenant: other_tenant)
        
        get :index, params: { tenant_id: tenant.id }
        
        expect(json_response[:data].size).to eq(3)
        expect(json_response[:data].all? { |u| u[:tenant_id] == tenant.id.to_s }).to be true
      end

      it "filters by status" do
        create(:user, :active)
        create(:user, :suspended)
        create(:user, :pending)
        
        get :index, params: { status: "active" }
        
        expect(json_response[:data].size).to be >= 1
        expect(json_response[:data].all? { |u| u[:status] == "active" }).to be true
      end

      it "filters by email" do
        create(:user, email: "search@example.com")
        create(:user, email: "other@example.com")
        
        get :index, params: { email: "search" }
        
        expect(json_response[:data].size).to eq(1)
        expect(json_response[:data].first[:email]).to eq("search@example.com")
      end

      it "filters by name" do
        create(:user, first_name: "John")
        create(:user, first_name: "Jane")
        
        get :index, params: { name: "John" }
        
        expect(json_response[:data].size).to eq(1)
        expect(json_response[:data].first[:first_name]).to eq("John")
      end

      it "filters by role" do
        create(:user, :admin)
        create(:user, :viewer)
        create(:user)
        
        get :index, params: { role: "admin" }
        
        expect(json_response[:data].size).to be >= 1
        expect(json_response[:data].all? { |u| u[:roles].include?("admin") }).to be true
      end

      it "paginates results" do
        create_list(:user, 30)
        
        get :index, params: { per_page: 10 }
        
        expect(json_response[:data].size).to eq(10)
        expect(json_response[:meta][:total_count]).to be >= 30
        expect(json_response[:meta][:total_pages]).to be >= 3
      end

      it "orders by name" do
        create(:user, first_name: "Zoe", last_name: "Zander")
        create(:user, first_name: "Alice", last_name: "Adams")
        
        get :index
        
        names = json_response[:data].map { |u| u[:first_name] }
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

      it "returns user details" do
        get :show, params: { id: regular_user.id }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:success]).to be true
        expect(json_response[:data][:id]).to eq(regular_user.id.to_s)
        expect(json_response[:data][:email]).to eq(regular_user.email)
      end
    end

    context "with tenant admin" do
      before do
        admin.update(tenant: tenant)
        regular_user.update(tenant: tenant)
        set_auth_headers(admin)
      end

      it "returns user details" do
        get :show, params: { id: regular_user.id }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:data][:id]).to eq(regular_user.id.to_s)
      end
    end

    context "with user from different tenant" do
      before do
        regular_user.update(tenant: other_tenant)
        set_auth_headers(regular_user)
      end

      it "returns forbidden" do
        get :show, params: { id: admin.id }
        
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with non-existent user" do
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

      it "creates a new user" do
        user_params = {
          user: {
            email: "newuser@example.com",
            first_name: "New",
            last_name: "User",
            password: "TestPassword123!",
            password_confirmation: "TestPassword123!"
          }
        }
        
        expect {
          post :create, params: user_params
        }.to change(User, :count).by(1)
        
        expect(response).to have_http_status(:created)
        expect(json_response[:success]).to be true
        expect(json_response[:data][:email]).to eq("newuser@example.com")
        expect(json_response[:message]).to eq("User created successfully")
      end

      it "creates user in specified tenant" do
        user_params = {
          user: {
            email: "tenantuser@example.com",
            first_name: "Tenant",
            last_name: "User",
            password: "TestPassword123!",
            password_confirmation: "TestPassword123!"
          },
          tenant_id: tenant.id
        }
        
        post :create, params: user_params
        
        expect(json_response[:data][:tenant_id]).to eq(tenant.id.to_s)
      end

      it "assigns roles" do
        user_params = {
          user: {
            email: "adminuser@example.com",
            first_name: "Admin",
            last_name: "User",
            password: "TestPassword123!",
            password_confirmation: "TestPassword123!"
          },
          role_names: ["admin", "viewer"]
        }
        
        post :create, params: user_params
        
        expect(json_response[:data][:roles]).to include("admin", "viewer")
      end

      it "returns validation errors" do
        user_params = {
          user: {
            email: "", # Invalid: email is required
            first_name: "Test"
          }
        }
        
        post :create, params: user_params
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:success]).to be false
        expect(json_response[:error]).to eq("validation_failed")
        expect(json_response[:details]).to include("Email can't be blank")
      end

      it "respects tenant user limit" do
        tenant.update(max_users: 1)
        create(:user, tenant: tenant)
        
        user_params = {
          user: {
            email: "overlimit@example.com",
            first_name: "Over",
            last_name: "Limit",
            password: "TestPassword123!",
            password_confirmation: "TestPassword123!"
          },
          tenant_id: tenant.id
        }
        
        post :create, params: user_params
        
        expect(response).to have_http_status(:forbidden)
        expect(json_response[:error]).to eq("limit_reached")
      end
    end

    context "with tenant admin" do
      before do
        admin.update(tenant: tenant)
        set_auth_headers(admin)
      end

      it "creates user in own tenant" do
        user_params = {
          user: {
            email: "tenantuser@example.com",
            first_name: "Tenant",
            last_name: "User",
            password: "TestPassword123!",
            password_confirmation: "TestPassword123!"
          }
        }
        
        expect {
          post :create, params: user_params
        }.to change(User, :count).by(1)
        
        expect(json_response[:data][:tenant_id]).to eq(tenant.id.to_s)
      end

      it "cannot create user in other tenant" do
        user_params = {
          user: {
            email: "otheruser@example.com",
            first_name: "Other",
            last_name: "User",
            password: "TestPassword123!",
            password_confirmation: "TestPassword123!"
          },
          tenant_id: other_tenant.id
        }
        
        post :create, params: user_params
        
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with regular user" do
      before { set_auth_headers(regular_user) }

      it "returns unauthorized" do
        post :create, params: { user: { email: "test@example.com" } }
        
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH #update" do
    context "with super admin" do
      before { set_auth_headers(super_admin) }

      it "updates user" do
        patch :update, params: {
          id: regular_user.id,
          user: {
            first_name: "Updated",
            last_name: "Name"
          }
        }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:success]).to be true
        expect(json_response[:data][:first_name]).to eq("Updated")
        expect(json_response[:message]).to eq("User updated successfully")
      end

      it "updates roles" do
        patch :update, params: {
          id: regular_user.id,
          user: {},
          role_names: ["admin"]
        }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:data][:roles]).to include("admin")
      end

      it "returns validation errors" do
        patch :update, params: {
          id: regular_user.id,
          user: {
            email: "" # Invalid
          }
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error]).to eq("validation_failed")
      end
    end

    context "with tenant admin" do
      before do
        admin.update(tenant: tenant)
        regular_user.update(tenant: tenant)
        set_auth_headers(admin)
      end

      it "updates user in own tenant" do
        patch :update, params: {
          id: regular_user.id,
          user: {
            first_name: "Updated"
          }
        }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:data][:first_name]).to eq("Updated")
      end
    end

    context "with user from different tenant" do
      before do
        regular_user.update(tenant: other_tenant)
        set_auth_headers(regular_user)
      end

      it "returns forbidden" do
        patch :update, params: {
          id: admin.id,
          user: { first_name: "Should not update" }
        }
        
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "DELETE #destroy" do
    context "with super admin" do
      before { set_auth_headers(super_admin) }

      it "soft deletes user" do
        delete :destroy, params: { id: regular_user.id }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:success]).to be true
        expect(json_response[:message]).to eq("User deleted successfully")
        
        # Verify user is soft deleted
        regular_user.reload
        expect(regular_user).to be_deleted
      end

      it "returns not found for non-existent user" do
        delete :destroy, params: { id: SecureRandom.uuid }
        
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with tenant admin" do
      before do
        admin.update(tenant: tenant)
        regular_user.update(tenant: tenant)
        set_auth_headers(admin)
      end

      it "deletes user in own tenant" do
        delete :destroy, params: { id: regular_user.id }
        
        expect(response).to have_http_status(:success)
        regular_user.reload
        expect(regular_user).to be_deleted
      end
    end

    context "with user trying to delete self" do
      before { set_auth_headers(regular_user) }

      it "returns forbidden" do
        delete :destroy, params: { id: regular_user.id }
        
        expect(response).to have_http_status(:forbidden)
        expect(json_response[:error]).to eq("cannot_delete_self")
      end
    end
  end

  describe "POST #restore" do
    let(:deleted_user) { create(:user) }

    before do
      deleted_user.soft_delete
    end

    context "with super admin" do
      before { set_auth_headers(super_admin) }

      it "restores deleted user" do
        post :restore, params: { id: deleted_user.id }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:success]).to be true
        expect(json_response[:message]).to eq("User restored successfully")
        
        # Verify user is restored
        deleted_user.reload
        expect(deleted_user).to be_active
      end

      it "returns not found for non-existent user" do
        post :restore, params: { id: SecureRandom.uuid }
        
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with tenant admin" do
      before do
        admin.update(tenant: tenant)
        deleted_user.update(tenant: tenant)
        set_auth_headers(admin)
      end

      it "restores user in own tenant" do
        post :restore, params: { id: deleted_user.id }
        
        expect(response).to have_http_status(:success)
        deleted_user.reload
        expect(deleted_user).to be_active
      end
    end
  end

  describe "POST #suspend" do
    context "with super admin" do
      before { set_auth_headers(super_admin) }

      it "suspends user" do
        post :suspend, params: { id: regular_user.id }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:success]).to be true
        expect(json_response[:message]).to eq("User suspended successfully")
        
        regular_user.reload
        expect(regular_user.status).to eq("suspended")
      end
    end

    context "with tenant admin" do
      before do
        admin.update(tenant: tenant)
        regular_user.update(tenant: tenant)
        set_auth_headers(admin)
      end

      it "suspends user in own tenant" do
        post :suspend, params: { id: regular_user.id }
        
        expect(response).to have_http_status(:success)
        regular_user.reload
        expect(regular_user.status).to eq("suspended")
      end
    end

    context "with user trying to suspend self" do
      before { set_auth_headers(regular_user) }

      it "returns forbidden" do
        post :suspend, params: { id: regular_user.id }
        
        expect(response).to have_http_status(:forbidden)
        expect(json_response[:error]).to eq("cannot_suspend_self")
      end
    end
  end

  describe "POST #reactivate" do
    let(:suspended_user) { create(:user, :suspended) }

    context "with super admin" do
      before { set_auth_headers(super_admin) }

      it "reactivates suspended user" do
        post :reactivate, params: { id: suspended_user.id }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:success]).to be true
        expect(json_response[:message]).to eq("User reactivated successfully")
        
        suspended_user.reload
        expect(suspended_user.status).to eq("active")
      end
    end

    context "with tenant admin" do
      before do
        admin.update(tenant: tenant)
        suspended_user.update(tenant: tenant)
        set_auth_headers(admin)
      end

      it "reactivates user in own tenant" do
        post :reactivate, params: { id: suspended_user.id }
        
        expect(response).to have_http_status(:success)
        suspended_user.reload
        expect(suspended_user.status).to eq("active")
      end
    end
  end

  describe "POST #reset_password" do
    context "with super admin" do
      before { set_auth_headers(super_admin) }

      it "resets user password" do
        new_password = "NewPassword123!"
        
        post :reset_password, params: {
          id: regular_user.id,
          new_password: new_password
        }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:success]).to be true
        expect(json_response[:message]).to eq("Password reset successfully")
        
        # Verify password was changed
        regular_user.reload
        expect(regular_user.valid_password?(new_password)).to be true
      end

      it "returns error for short password" do
        post :reset_password, params: {
          id: regular_user.id,
          new_password: "short"
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error]).to eq("password_too_short")
      end

      it "returns error for missing password" do
        post :reset_password, params: { id: regular_user.id }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error]).to eq("password_required")
      end
    end

    context "with tenant admin" do
      before do
        admin.update(tenant: tenant)
        regular_user.update(tenant: tenant)
        set_auth_headers(admin)
      end

      it "resets password for user in own tenant" do
        new_password = "NewPassword123!"
        
        post :reset_password, params: {
          id: regular_user.id,
          new_password: new_password
        }
        
        expect(response).to have_http_status(:success)
        regular_user.reload
        expect(regular_user.valid_password?(new_password)).to be true
      end
    end
  end

  describe "GET #audit_logs" do
    context "with super admin" do
      before { set_auth_headers(super_admin) }

      it "returns user audit logs" do
        create_list(:audit_log, 3, actor: regular_user)
        
        get :audit_logs, params: { id: regular_user.id }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:success]).to be true
        expect(json_response[:data].size).to eq(3)
      end

      it "filters by action" do
        create(:audit_log, actor: regular_user, action: "create")
        create(:audit_log, actor: regular_user, action: "update")
        
        get :audit_logs, params: { id: regular_user.id, action: "create" }
        
        expect(json_response[:data].size).to eq(1)
        expect(json_response[:data].first[:action]).to eq("create")
      end

      it "filters by resource type" do
        create(:audit_log, actor: regular_user, resource_type: "User")
        create(:audit_log, actor: regular_user, resource_type: "Tenant")
        
        get :audit_logs, params: { id: regular_user.id, resource_type: "User" }
        
        expect(json_response[:data].size).to eq(1)
        expect(json_response[:data].first[:resource_type]).to eq("User")
      end

      it "paginates results" do
        create_list(:audit_log, 30, actor: regular_user)
        
        get :audit_logs, params: { id: regular_user.id, per_page: 10 }
        
        expect(json_response[:data].size).to eq(10)
        expect(json_response[:meta][:total_count]).to eq(30)
      end
    end

    context "with tenant admin" do
      before do
        admin.update(tenant: tenant)
        regular_user.update(tenant: tenant)
        set_auth_headers(admin)
      end

      it "returns audit logs for user in own tenant" do
        create(:audit_log, actor: regular_user)
        
        get :audit_logs, params: { id: regular_user.id }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:data].size).to be >= 1
      end
    end
  end

  # Test user serializer
  describe "user serialization" do
    before { set_auth_headers(super_admin) }

    it "includes all expected fields" do
      get :show, params: { id: regular_user.id }
      
      user_data = json_response[:data]
      
      expect(user_data).to have_key(:id)
      expect(user_data).to have_key(:email)
      expect(user_data).to have_key(:first_name)
      expect(user_data).to have_key(:last_name)
      expect(user_data).to have_key(:full_name)
      expect(user_data).to have_key(:display_name)
      expect(user_data).to have_key(:status)
      expect(user_data).to have_key(:tenant_id)
      expect(user_data).to have_key(:tenant_name)
      expect(user_data).to have_key(:roles)
      expect(user_data).to have_key(:permissions)
      expect(user_data).to have_key(:phone)
      expect(user_data).to have_key(:job_title)
      expect(user_data).to have_key(:department)
      expect(user_data).to have_key(:avatar_url)
      expect(user_data).to have_key(:timezone)
      expect(user_data).to have_key(:locale)
      expect(user_data).to have_key(:mfa_enabled)
      expect(user_data).to have_key(:mfa_required)
      expect(user_data).to have_key(:can_manage_tenant)
      expect(user_data).to have_key(:can_manage_users)
      expect(user_data).to have_key(:can_manage_settings)
      expect(user_data).to have_key(:created_at)
      expect(user_data).to have_key(:updated_at)
      expect(user_data).to have_key(:last_active_at)
    end
  end

  # Test audit log serializer
  describe "audit log serialization" do
    let(:audit_log) { create(:audit_log, actor: regular_user) }

    before do
      set_auth_headers(super_admin)
      audit_log
    end

    it "includes all expected fields" do
      get :audit_logs, params: { id: regular_user.id }
      
      log_data = json_response[:data].first
      
      expect(log_data).to have_key(:id)
      expect(log_data).to have_key(:action)
      expect(log_data).to have_key(:resource_type)
      expect(log_data).to have_key(:resource_id)
      expect(log_data).to have_key(:changes)
      expect(log_data).to have_key(:metadata)
      expect(log_data).to have_key(:ip_address)
      expect(log_data).to have_key(:user_agent)
      expect(log_data).to have_key(:created_at)
    end
  end
end
