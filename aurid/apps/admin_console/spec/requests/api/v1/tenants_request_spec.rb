require 'rails_helper'

RSpec.describe "API V1 Tenants Requests", type: :request do
  let(:tenant) { create(:tenant) }
  let(:super_admin) { create(:user, :super_admin, :with_password, password: 'password123') }
  let(:tenant_admin) { create(:user, :tenant_admin, tenant: tenant, :with_password, password: 'password123') }
  let(:regular_user) { create(:user, tenant: tenant, :with_password, password: 'password123') }
  let(:headers) { { "Content-Type" => "application/json" } }

  def get_token(user)
    post "/api/v1/auth/login", params: { email: user.email, password: 'password123' }.to_json, headers: headers
    JSON.parse(response.body)["data"]["token"]
  end

  describe "GET /api/v1/tenants" do
    let(:path) { "/api/v1/tenants" }

    context "as super admin" do
      let(:token) { get_token(super_admin) }

      it "returns HTTP success" do
        get path, headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:success)
      end

      it "returns list of tenants" do
        create_list(:tenant, 5)
        
        get path, headers: { "Authorization" => "Bearer #{token}" }
        json = JSON.parse(response.body)
        
        expect(json["data"].size).to eq(6) # 5 created + 1 existing
      end

      it "returns tenant details" do
        get path, headers: { "Authorization" => "Bearer #{token}" }
        json = JSON.parse(response.body)
        
        tenant_data = json["data"].find { |t| t["id"] == tenant.id.to_s }
        expect(tenant_data["name"]).to eq(tenant.name)
        expect(tenant_data["domain"]).to eq(tenant.domain)
      end

      it "supports pagination" do
        create_list(:tenant, 25)
        
        get "#{path}?page=1&per_page=10", headers: { "Authorization" => "Bearer #{token}" }
        json = JSON.parse(response.body)
        
        expect(json["data"].size).to eq(10)
        expect(json["meta"]["total_pages"]).to eq(3)
        expect(json["meta"]["current_page"]).to eq(1)
        expect(json["meta"]["total_count"]).to eq(26)
      end

      it "supports filtering by name" do
        create(:tenant, name: "Filter Test")
        
        get "#{path}?name=Filter", headers: { "Authorization" => "Bearer #{token}" }
        json = JSON.parse(response.body)
        
        expect(json["data"].size).to eq(1)
        expect(json["data"][0]["name"]).to eq("Filter Test")
      end

      it "supports filtering by domain" do
        create(:tenant, domain: "filtertest.com")
        
        get "#{path}?domain=filtertest.com", headers: { "Authorization" => "Bearer #{token}" }
        json = JSON.parse(response.body)
        
        expect(json["data"].size).to eq(1)
        expect(json["data"][0]["domain"]).to eq("filtertest.com")
      end

      it "supports filtering by status" do
        create(:tenant, status: :suspended)
        
        get "#{path}?status=suspended", headers: { "Authorization" => "Bearer #{token}" }
        json = JSON.parse(response.body)
        
        expect(json["data"].size).to eq(1)
        expect(json["data"][0]["status"]).to eq("suspended")
      end

      it "supports sorting" do
        create(:tenant, name: "Zebra")
        create(:tenant, name: "Alpha")
        
        get "#{path}?sort=name&direction=asc", headers: { "Authorization" => "Bearer #{token}" }
        json = JSON.parse(response.body)
        
        names = json["data"].map { |t| t["name"] }
        expect(names).to eq(names.sort)
      end
    end

    context "as tenant admin" do
      let(:token) { get_token(tenant_admin) }

      it "returns HTTP success" do
        get path, headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:success)
      end

      it "returns only own tenant" do
        get path, headers: { "Authorization" => "Bearer #{token}" }
        json = JSON.parse(response.body)
        
        expect(json["data"].size).to eq(1)
        expect(json["data"][0]["id"]).to eq(tenant.id.to_s)
      end
    end

    context "as regular user" do
      let(:token) { get_token(regular_user) }

      it "returns HTTP forbidden" do
        get path, headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:forbidden)
      end

      it "returns forbidden error" do
        get path, headers: { "Authorization" => "Bearer #{token}" }
        json = JSON.parse(response.body)
        
        expect(json["error"]).to eq("forbidden")
        expect(json["message"]).to eq("You are not authorized to perform this action")
      end
    end

    context "without authentication" do
      it "returns HTTP unauthorized" do
        get path
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/tenants" do
    let(:path) { "/api/v1/tenants" }

    context "as super admin" do
      let(:token) { get_token(super_admin) }

      it "returns HTTP created" do
        post path, params: {
          tenant: {
            name: "New Tenant",
            domain: "newtenant.com",
            description: "A new tenant"
          }
        }.to_json, headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
        
        expect(response).to have_http_status(:created)
      end

      it "creates a new tenant" do
        expect {
          post path, params: {
            tenant: {
              name: "New Tenant",
              domain: "newtenant.com"
            }
          }.to_json, headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
        }.to change(Tenant, :count).by(1)
      end

      it "returns the created tenant" do
        post path, params: {
          tenant: {
            name: "New Tenant",
            domain: "newtenant.com"
          }
        }.to_json, headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
        
        json = JSON.parse(response.body)
        expect(json["data"]["name"]).to eq("New Tenant")
        expect(json["data"]["domain"]).to eq("newtenant.com")
        expect(json["data"]["id"]).to be_present
      end

      it "creates tenant with settings" do
        post path, params: {
          tenant: {
            name: "Settings Tenant",
            domain: "settingstenant.com",
            settings: {
              max_users: 100,
              storage_quota_gb: 500,
              sso_enabled: true
            }
          }
        }.to_json, headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
        
        json = JSON.parse(response.body)
        tenant = Tenant.find(json["data"]["id"])
        
        expect(tenant.settings["max_users"]).to eq(100)
        expect(tenant.settings["storage_quota_gb"]).to eq(500)
        expect(tenant.settings["sso_enabled"]).to be true
      end

      it "returns validation errors for invalid data" do
        post path, params: {
          tenant: {
            name: "",
            domain: "invalid domain"
          }
        }.to_json, headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        
        expect(json["errors"]["name"]).to include("can't be blank")
        expect(json["errors"]["domain"]).to include("is invalid")
      end

      it "prevents duplicate domain names" do
        existing_tenant = create(:tenant, domain: "taken.com")
        
        post path, params: {
          tenant: {
            name: "Duplicate",
            domain: "taken.com"
          }
        }.to_json, headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        
        expect(json["errors"]["domain"]).to include("has already been taken")
      end
    end

    context "as tenant admin" do
      let(:token) { get_token(tenant_admin) }

      it "returns HTTP forbidden" do
        post path, params: {
          tenant: {
            name: "New Tenant",
            domain: "newtenant.com"
          }
        }.to_json, headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
        
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as regular user" do
      let(:token) { get_token(regular_user) }

      it "returns HTTP forbidden" do
        post path, params: {
          tenant: {
            name: "New Tenant",
            domain: "newtenant.com"
          }
        }.to_json, headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
        
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "without authentication" do
      it "returns HTTP unauthorized" do
        post path, params: {
          tenant: {
            name: "New Tenant",
            domain: "newtenant.com"
          }
        }.to_json, headers: headers
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/tenants/:id" do
    let(:path) { "/api/v1/tenants/#{tenant.id}" }

    context "as super admin" do
      let(:token) { get_token(super_admin) }

      it "returns HTTP success" do
        get path, headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:success)
      end

      it "returns tenant details" do
        get path, headers: { "Authorization" => "Bearer #{token}" }
        json = JSON.parse(response.body)
        
        expect(json["data"]["id"]).to eq(tenant.id.to_s)
        expect(json["data"]["name"]).to eq(tenant.name)
        expect(json["data"]["domain"]).to eq(tenant.domain)
        expect(json["data"]["description"]).to eq(tenant.description)
      end

      it "returns tenant settings" do
        tenant.update!(settings: { max_users: 100, sso_enabled: true })
        
        get path, headers: { "Authorization" => "Bearer #{token}" }
        json = JSON.parse(response.body)
        
        expect(json["data"]["settings"]["max_users"]).to eq(100)
        expect(json["data"]["settings"]["sso_enabled"]).to be true
      end

      it "returns tenant statistics" do
        create_list(:user, 5, tenant: tenant)
        
        get path, headers: { "Authorization" => "Bearer #{token}" }
        json = JSON.parse(response.body)
        
        expect(json["data"]["statistics"]["user_count"]).to eq(5)
      end

      it "returns created and updated timestamps" do
        get path, headers: { "Authorization" => "Bearer #{token}" }
        json = JSON.parse(response.body)
        
        expect(json["data"]["created_at"]).to be_present
        expect(json["data"]["updated_at"]).to be_present
      end
    end

    context "as tenant admin of the tenant" do
      let(:token) { get_token(tenant_admin) }

      it "returns HTTP success" do
        get path, headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:success)
      end

      it "returns tenant details" do
        get path, headers: { "Authorization" => "Bearer #{token}" }
        json = JSON.parse(response.body)
        
        expect(json["data"]["id"]).to eq(tenant.id.to_s)
      end
    end

    context "as tenant admin of different tenant" do
      let(:other_tenant) { create(:tenant) }
      let(:other_tenant_admin) { create(:user, :tenant_admin, tenant: other_tenant, :with_password, password: 'password123') }
      let(:token) { get_token(other_tenant_admin) }
      let(:path) { "/api/v1/tenants/#{tenant.id}" }

      it "returns HTTP forbidden" do
        get path, headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as regular user" do
      let(:token) { get_token(regular_user) }

      it "returns HTTP forbidden" do
        get path, headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with non-existent tenant" do
      let(:token) { get_token(super_admin) }

      it "returns HTTP not found" do
        get "/api/v1/tenants/#{SecureRandom.uuid}", headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:not_found)
      end

      it "returns not found error" do
        get "/api/v1/tenants/#{SecureRandom.uuid}", headers: { "Authorization" => "Bearer #{token}" }
        json = JSON.parse(response.body)
        
        expect(json["error"]).to eq("not_found")
        expect(json["message"]).to eq("Tenant not found")
      end
    end

    context "without authentication" do
      it "returns HTTP unauthorized" do
        get path
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PUT /api/v1/tenants/:id" do
    let(:path) { "/api/v1/tenants/#{tenant.id}" }

    context "as super admin" do
      let(:token) { get_token(super_admin) }

      it "returns HTTP success" do
        put path, params: {
          tenant: {
            name: "Updated Tenant",
            description: "Updated description"
          }
        }.to_json, headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
        
        expect(response).to have_http_status(:success)
      end

      it "updates tenant information" do
        put path, params: {
          tenant: {
            name: "Updated Tenant",
            description: "Updated description"
          }
        }.to_json, headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
        
        tenant.reload
        expect(tenant.name).to eq("Updated Tenant")
        expect(tenant.description).to eq("Updated description")
      end

      it "updates tenant settings" do
        put path, params: {
          tenant: {
            settings: {
              max_users: 200,
              storage_quota_gb: 1000,
              sso_enabled: true
            }
          }
        }.to_json, headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
        
        tenant.reload
        expect(tenant.settings["max_users"]).to eq(200)
        expect(tenant.settings["storage_quota_gb"]).to eq(1000)
        expect(tenant.settings["sso_enabled"]).to be true
      end

      it "returns updated tenant" do
        put path, params: {
          tenant: {
            name: "Updated Tenant"
          }
        }.to_json, headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
        
        json = JSON.parse(response.body)
        expect(json["data"]["name"]).to eq("Updated Tenant")
      end

      it "returns validation errors" do
        put path, params: {
          tenant: {
            name: ""
          }
        }.to_json, headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        
        expect(json["errors"]["name"]).to include("can't be blank")
      end

      it "prevents changing domain to existing domain" do
        existing_tenant = create(:tenant, domain: "taken.com")
        
        put path, params: {
          tenant: {
            domain: "taken.com"
          }
        }.to_json, headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        
        expect(json["errors"]["domain"]).to include("has already been taken")
      end
    end

    context "as tenant admin of the tenant" do
      let(:token) { get_token(tenant_admin) }

      it "returns HTTP success" do
        put path, params: {
          tenant: {
            name: "Updated Tenant"
          }
        }.to_json, headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
        
        expect(response).to have_http_status(:success)
      end

      it "updates tenant information" do
        put path, params: {
          tenant: {
            description: "Updated by tenant admin"
          }
        }.to_json, headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
        
        tenant.reload
        expect(tenant.description).to eq("Updated by tenant admin")
      end

      it "cannot change domain" do
        put path, params: {
          tenant: {
            domain: "newdomain.com"
          }
        }.to_json, headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
        
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as tenant admin of different tenant" do
      let(:other_tenant) { create(:tenant) }
      let(:other_tenant_admin) { create(:user, :tenant_admin, tenant: other_tenant, :with_password, password: 'password123') }
      let(:token) { get_token(other_tenant_admin) }
      let(:path) { "/api/v1/tenants/#{tenant.id}" }

      it "returns HTTP forbidden" do
        put path, params: {
          tenant: {
            name: "Updated"
          }
        }.to_json, headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
        
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as regular user" do
      let(:token) { get_token(regular_user) }

      it "returns HTTP forbidden" do
        put path, params: {
          tenant: {
            name: "Updated"
          }
        }.to_json, headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
        
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with non-existent tenant" do
      let(:token) { get_token(super_admin) }

      it "returns HTTP not found" do
        put "/api/v1/tenants/#{SecureRandom.uuid}", params: {
          tenant: {
            name: "Updated"
          }
        }.to_json, headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
        
        expect(response).to have_http_status(:not_found)
      end
    end

    context "without authentication" do
      it "returns HTTP unauthorized" do
        put path, params: {
          tenant: {
            name: "Updated"
          }
        }.to_json, headers: headers
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/tenants/:id" do
    let!(:tenant_to_delete) { create(:tenant, name: "To Delete") }
    let(:path) { "/api/v1/tenants/#{tenant_to_delete.id}" }

    context "as super admin" do
      let(:token) { get_token(super_admin) }

      it "returns HTTP no content" do
        delete path, headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:no_content)
      end

      it "soft deletes tenant" do
        delete path, headers: { "Authorization" => "Bearer #{token}" }
        
        expect(Tenant.with_deleted.find(tenant_to_delete.id)).to be_present
        expect(Tenant.find_by(id: tenant_to_delete.id)).to be_nil
      end

      it "prevents deletion of tenant with users" do
        create(:user, tenant: tenant_to_delete)
        
        delete path, headers: { "Authorization" => "Bearer #{token}" }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        
        expect(json["error"]).to eq("cannot_delete_tenant_with_users")
        expect(json["message"]).to eq("Cannot delete tenant with users")
      end

      it "force deletes tenant" do
        delete "#{path}?force=true", headers: { "Authorization" => "Bearer #{token}" }
        
        expect(Tenant.with_deleted.find_by(id: tenant_to_delete.id)).to be_nil
      end
    end

    context "as tenant admin of the tenant" do
      let(:tenant_admin) { create(:user, :tenant_admin, tenant: tenant_to_delete, :with_password, password: 'password123') }
      let(:token) { get_token(tenant_admin) }

      it "returns HTTP forbidden" do
        delete path, headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as regular user" do
      let(:regular_user) { create(:user, tenant: tenant_to_delete, :with_password, password: 'password123') }
      let(:token) { get_token(regular_user) }

      it "returns HTTP forbidden" do
        delete path, headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with non-existent tenant" do
      let(:token) { get_token(super_admin) }

      it "returns HTTP not found" do
        delete "/api/v1/tenants/#{SecureRandom.uuid}", headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "without authentication" do
      it "returns HTTP unauthorized" do
        delete path
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/tenants/:id/suspend" do
    let(:path) { "/api/v1/tenants/#{tenant.id}/suspend" }

    context "as super admin" do
      let(:token) { get_token(super_admin) }

      it "returns HTTP success" do
        patch path, headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:success)
      end

      it "suspends the tenant" do
        patch path, headers: { "Authorization" => "Bearer #{token}" }
        
        tenant.reload
        expect(tenant).to be_suspended
      end

      it "returns suspended tenant" do
        patch path, headers: { "Authorization" => "Bearer #{token}" }
        json = JSON.parse(response.body)
        
        expect(json["data"]["status"]).to eq("suspended")
      end
    end

    context "as tenant admin of the tenant" do
      let(:token) { get_token(tenant_admin) }

      it "returns HTTP forbidden" do
        patch path, headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "without authentication" do
      it "returns HTTP unauthorized" do
        patch path
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/tenants/:id/activate" do
    let(:path) { "/api/v1/tenants/#{tenant.id}/activate" }

    before do
      tenant.suspend!
    end

    context "as super admin" do
      let(:token) { get_token(super_admin) }

      it "returns HTTP success" do
        patch path, headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:success)
      end

      it "activates the tenant" do
        patch path, headers: { "Authorization" => "Bearer #{token}" }
        
        tenant.reload
        expect(tenant).not_to be_suspended
      end

      it "returns activated tenant" do
        patch path, headers: { "Authorization" => "Bearer #{token}" }
        json = JSON.parse(response.body)
        
        expect(json["data"]["status"]).to eq("active")
      end
    end

    context "as tenant admin of the tenant" do
      let(:token) { get_token(tenant_admin) }

      it "returns HTTP forbidden" do
        patch path, headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "without authentication" do
      it "returns HTTP unauthorized" do
        patch path
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
