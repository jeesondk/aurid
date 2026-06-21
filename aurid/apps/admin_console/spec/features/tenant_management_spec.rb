require 'rails_helper'

RSpec.describe "Tenant Management Features", type: :feature do
  let(:super_admin) { create(:user, :super_admin) }
  let(:tenant_admin) { create(:user, :tenant_admin) }
  let(:tenant) { tenant_admin.tenant }

  describe "Tenant CRUD Operations" do
    before do
      sign_in super_admin
    end

    describe "Tenant Creation" do
      it "creates a new tenant with valid data" do
        visit new_tenant_path
        
        fill_in "Name", with: "Acme Corporation"
        fill_in "Domain", with: "acme.com"
        fill_in "Description", with: "A test tenant"
        select "Germany", from: "Region"
        choose "Enterprise"
        
        click_button "Create Tenant"
        
        expect(page).to have_current_path(tenant_path(Tenant.last))
        expect(page).to have_content("Tenant created successfully")
        expect(page).to have_content("Acme Corporation")
        expect(page).to have_content("acme.com")
      end

      it "shows validation errors for invalid data" do
        visit new_tenant_path
        
        # Try to create with invalid data
        fill_in "Name", with: ""
        fill_in "Domain", with: "invalid domain"
        click_button "Create Tenant"
        
        expect(page).to have_current_path(tenants_path)
        expect(page).to have_content("Name can't be blank")
        expect(page).to have_content("Domain is invalid")
      end

      it "prevents duplicate domain names" do
        existing_tenant = create(:tenant, domain: "existing.com")
        
        visit new_tenant_path
        
        fill_in "Name", with: "Duplicate Tenant"
        fill_in "Domain", with: "existing.com"
        click_button "Create Tenant"
        
        expect(page).to have_current_path(tenants_path)
        expect(page).to have_content("Domain has already been taken")
      end

      it "creates tenant with custom settings" do
        visit new_tenant_path
        
        fill_in "Name", with: "Custom Tenant"
        fill_in "Domain", with: "custom.example.com"
        fill_in "Max users", with: "100"
        fill_in "Storage quota (GB)", with: "500"
        check "Enable SSO"
        check "Enable audit logging"
        
        click_button "Create Tenant"
        
        expect(page).to have_current_path(tenant_path(Tenant.last))
        tenant = Tenant.last
        expect(tenant.settings["max_users"]).to eq(100)
        expect(tenant.settings["storage_quota_gb"]).to eq(500)
        expect(tenant.settings["sso_enabled"]).to be true
        expect(tenant.settings["audit_logging_enabled"]).to be true
      end
    end

    describe "Tenant Viewing" do
      let!(:tenant1) { create(:tenant, name: "Tenant 1", domain: "tenant1.com") }
      let!(:tenant2) { create(:tenant, name: "Tenant 2", domain: "tenant2.com") }

      it "displays all tenants in a list" do
        visit tenants_path
        
        expect(page).to have_content("Tenant 1")
        expect(page).to have_content("tenant1.com")
        expect(page).to have_content("Tenant 2")
        expect(page).to have_content("tenant2.com")
      end

      it "shows tenant details" do
        visit tenant_path(tenant1)
        
        expect(page).to have_content("Tenant 1")
        expect(page).to have_content("tenant1.com")
        expect(page).to have_content("Created at")
        expect(page).to have_content("Updated at")
      end

      it "shows tenant statistics" do
        create_list(:user, 5, tenant: tenant1)
        create_list(:user, 3, tenant: tenant2)
        
        visit tenant_path(tenant1)
        
        expect(page).to have_content("5 users")
        expect(page).to have_content("Statistics")
      end

      it "filters tenants by name" do
        visit tenants_path
        
        fill_in "Search", with: "Tenant 1"
        click_button "Search"
        
        expect(page).to have_content("Tenant 1")
        expect(page).not_to have_content("Tenant 2")
      end

      it "filters tenants by domain" do
        visit tenants_path
        
        fill_in "Search", with: "tenant2.com"
        click_button "Search"
        
        expect(page).to have_content("Tenant 2")
        expect(page).not_to have_content("Tenant 1")
      end

      it "paginates tenants" do
        create_list(:tenant, 25)
        
        visit tenants_path
        
        expect(page).to have_selector(".pagination")
        expect(page).to have_selector(".tenant-row", count: 20) # First page
      end
    end

    describe "Tenant Editing" do
      let(:tenant) { create(:tenant, name: "Original Name", domain: "original.com") }

      it "updates tenant information" do
        visit edit_tenant_path(tenant)
        
        fill_in "Name", with: "Updated Name"
        fill_in "Description", with: "Updated description"
        click_button "Update Tenant"
        
        expect(page).to have_current_path(tenant_path(tenant))
        expect(page).to have_content("Tenant updated successfully")
        expect(page).to have_content("Updated Name")
        expect(page).to have_content("Updated description")
      end

      it "updates tenant settings" do
        visit edit_tenant_path(tenant)
        
        fill_in "Max users", with: "200"
        check "Enable SSO"
        click_button "Update Tenant"
        
        tenant.reload
        expect(tenant.settings["max_users"]).to eq(200)
        expect(tenant.settings["sso_enabled"]).to be true
      end

      it "shows validation errors when updating" do
        visit edit_tenant_path(tenant)
        
        fill_in "Name", with: ""
        click_button "Update Tenant"
        
        expect(page).to have_current_path(tenant_path(tenant))
        expect(page).to have_content("Name can't be blank")
      end

      it "prevents changing domain to existing domain" do
        existing_tenant = create(:tenant, domain: "taken.com")
        
        visit edit_tenant_path(tenant)
        
        fill_in "Domain", with: "taken.com"
        click_button "Update Tenant"
        
        expect(page).to have_current_path(tenant_path(tenant))
        expect(page).to have_content("Domain has already been taken")
      end
    end

    describe "Tenant Deletion" do
      let!(:tenant) { create(:tenant, name: "To Delete") }

      it "deletes a tenant" do
        visit tenant_path(tenant)
        
        accept_confirm do
          click_link "Delete"
        end
        
        expect(page).to have_current_path(tenants_path)
        expect(page).to have_content("Tenant deleted successfully")
        expect(page).not_to have_content("To Delete")
      end

      it "prevents deletion of tenant with users" do
        create(:user, tenant: tenant)
        
        visit tenant_path(tenant)
        
        accept_confirm do
          click_link "Delete"
        end
        
        expect(page).to have_current_path(tenant_path(tenant))
        expect(page).to have_content("Cannot delete tenant with users")
      end

      it "soft deletes tenant by default" do
        visit tenant_path(tenant)
        
        accept_confirm do
          click_link "Delete"
        end
        
        expect(Tenant.with_deleted.find(tenant.id)).to be_present
        expect(Tenant.find_by(id: tenant.id)).to be_nil
      end

      it "hard deletes tenant when forced" do
        visit tenant_path(tenant)
        
        accept_confirm do
          click_link "Force Delete"
        end
        
        expect(Tenant.with_deleted.find_by(id: tenant.id)).to be_nil
      end
    end
  end

  describe "Tenant Suspension and Activation" do
    let(:tenant) { create(:tenant, name: "Suspendable Tenant") }

    before do
      sign_in super_admin
    end

    it "suspends a tenant" do
      visit tenant_path(tenant)
      
      click_link "Suspend"
      
      expect(page).to have_current_path(tenant_path(tenant))
      expect(page).to have_content("Tenant suspended successfully")
      
      tenant.reload
      expect(tenant).to be_suspended
    end

    it "activates a suspended tenant" do
      tenant.suspend!
      
      visit tenant_path(tenant)
      
      click_link "Activate"
      
      expect(page).to have_current_path(tenant_path(tenant))
      expect(page).to have_content("Tenant activated successfully")
      
      tenant.reload
      expect(tenant).not_to be_suspended
    end

    it "prevents actions on suspended tenants" do
      tenant.suspend!
      
      visit edit_tenant_path(tenant)
      
      expect(page).to have_current_path(tenant_path(tenant))
      expect(page).to have_content("Tenant is suspended")
    end

    it "shows suspended status in tenant list" do
      tenant.suspend!
      
      visit tenants_path
      
      expect(page).to have_content("Suspended")
      expect(page).to have_selector(".status-suspended")
    end
  end

  describe "Tenant User Management" do
    let(:tenant) { create(:tenant) }
    let(:tenant_admin) { create(:user, :tenant_admin, tenant: tenant) }

    before do
      sign_in super_admin
    end

    it "assigns admin to tenant during creation" do
      visit new_tenant_path
      
      fill_in "Name", with: "New Tenant"
      fill_in "Domain", with: "newtenant.com"
      fill_in "Admin Email", with: "admin@newtenant.com"
      fill_in "Admin Password", with: "password123"
      fill_in "Admin Password Confirmation", with: "password123"
      
      click_button "Create Tenant"
      
      expect(page).to have_current_path(tenant_path(Tenant.last))
      tenant = Tenant.last
      expect(tenant.users.count).to eq(1)
      expect(tenant.users.first.email).to eq("admin@newtenant.com")
      expect(tenant.users.first).to have_role(:tenant_admin)
    end

    it "adds existing user to tenant" do
      user = create(:user)
      
      visit tenant_path(tenant)
      
      click_link "Add User"
      select user.email, from: "User"
      select "Tenant Admin", from: "Role"
      click_button "Add"
      
      expect(page).to have_current_path(tenant_path(tenant))
      expect(page).to have_content("User added to tenant")
      
      user.reload
      expect(user.tenant).to eq(tenant)
      expect(user).to have_role(:tenant_admin)
    end

    it "removes user from tenant" do
      create(:user, tenant: tenant)
      
      visit tenant_path(tenant)
      
      within(".users-table") do
        click_link "Remove"
      end
      
      expect(page).to have_current_path(tenant_path(tenant))
      expect(page).to have_content("User removed from tenant")
    end

    it "changes user role within tenant" do
      user = create(:user, tenant: tenant)
      
      visit tenant_path(tenant)
      
      within(".users-table") do
        select "Tenant Admin", from: "Role"
        click_button "Update"
      end
      
      expect(page).to have_current_path(tenant_path(tenant))
      expect(page).to have_content("Role updated")
      
      user.reload
      expect(user).to have_role(:tenant_admin)
    end
  end

  describe "Tenant Settings Management" do
    let(:tenant) { create(:tenant) }

    before do
      sign_in super_admin
    end

    it "configures SSO settings" do
      visit edit_tenant_path(tenant)
      
      check "Enable SSO"
      fill_in "SSO Provider URL", with: "https://sso.example.com"
      fill_in "SSO Entity ID", with: "urn:example:tenant"
      fill_in "SSO Certificate", with: "-----BEGIN CERTIFICATE-----"
      
      click_button "Update Tenant"
      
      tenant.reload
      expect(tenant.settings["sso_enabled"]).to be true
      expect(tenant.settings["sso_provider_url"]).to eq("https://sso.example.com")
      expect(tenant.settings["sso_entity_id"]).to eq("urn:example:tenant")
    end

    it "configures branding settings" do
      visit edit_tenant_path(tenant)
      
      fill_in "Logo URL", with: "https://example.com/logo.png"
      fill_in "Primary Color", with: "#0066cc"
      fill_in "Secondary Color", with: "#ffffff"
      
      click_button "Update Tenant"
      
      tenant.reload
      expect(tenant.settings["logo_url"]).to eq("https://example.com/logo.png")
      expect(tenant.settings["primary_color"]).to eq("#0066cc")
      expect(tenant.settings["secondary_color"]).to eq("#ffffff")
    end

    it "configures security settings" do
      visit edit_tenant_path(tenant)
      
      check "Require MFA"
      check "Password complexity"
      fill_in "Password minimum length", with: "12"
      fill_in "Session timeout (minutes)", with: "30"
      
      click_button "Update Tenant"
      
      tenant.reload
      expect(tenant.settings["require_mfa"]).to be true
      expect(tenant.settings["password_complexity"]).to be true
      expect(tenant.settings["password_min_length"]).to eq(12)
      expect(tenant.settings["session_timeout_minutes"]).to eq(30)
    end

    it "configures storage settings" do
      visit edit_tenant_path(tenant)
      
      fill_in "Storage quota (GB)", with: "1000"
      fill_in "Max file size (MB)", with: "100"
      check "Enable versioning"
      
      click_button "Update Tenant"
      
      tenant.reload
      expect(tenant.settings["storage_quota_gb"]).to eq(1000)
      expect(tenant.settings["max_file_size_mb"]).to eq(100)
      expect(tenant.settings["versioning_enabled"]).to be true
    end
  end

  describe "Tenant Access Control" do
    let(:tenant) { create(:tenant) }
    let(:tenant_admin) { create(:user, :tenant_admin, tenant: tenant) }
    let(:other_tenant_admin) { create(:user, :tenant_admin) }

    context "as super admin" do
      before do
        sign_in super_admin
      end

      it "can access all tenants" do
        visit tenants_path
        
        expect(page).to have_content(tenant.name)
        expect(page).to have_content(other_tenant_admin.tenant.name)
      end

      it "can edit any tenant" do
        visit edit_tenant_path(tenant)
        
        expect(page).to have_http_status(:success)
      end

      it "can delete any tenant" do
        visit tenant_path(tenant)
        
        expect(page).to have_link("Delete")
      end
    end

    context "as tenant admin" do
      before do
        sign_in tenant_admin
      end

      it "can only see their own tenant" do
        visit tenants_path
        
        expect(page).to have_content(tenant.name)
        expect(page).not_to have_content(other_tenant_admin.tenant.name)
      end

      it "can edit their own tenant" do
        visit edit_tenant_path(tenant)
        
        expect(page).to have_http_status(:success)
      end

      it "cannot delete their own tenant" do
        visit tenant_path(tenant)
        
        expect(page).not_to have_link("Delete")
      end

      it "cannot access other tenants" do
        visit tenant_path(other_tenant_admin.tenant)
        
        expect(page).to have_current_path(root_path)
        expect(page).to have_content("Not authorized")
      end
    end
  end

  describe "Tenant API Endpoints" do
    let(:tenant) { create(:tenant) }
    let(:api_path) { "/api/v1/tenants" }

    describe "GET /api/v1/tenants" do
      it "returns list of tenants for super admin" do
        token = get_jwt_token(super_admin)
        
        get api_path, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json["data"].size).to be >= 1
        expect(json["data"][0]["id"]).to eq(tenant.id.to_s)
      end

      it "returns only own tenant for tenant admin" do
        token = get_jwt_token(tenant_admin)
        
        get api_path, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json["data"].size).to eq(1)
        expect(json["data"][0]["id"]).to eq(tenant_admin.tenant.id.to_s)
      end

      it "supports pagination" do
        create_list(:tenant, 25)
        token = get_jwt_token(super_admin)
        
        get "#{api_path}?page=1&per_page=10", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json["data"].size).to eq(10)
        expect(json["meta"]["total_pages"]).to eq(3)
        expect(json["meta"]["current_page"]).to eq(1)
      end

      it "supports filtering by name" do
        create(:tenant, name: "Filter Test")
        token = get_jwt_token(super_admin)
        
        get "#{api_path}?name=Filter", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json["data"].size).to eq(1)
        expect(json["data"][0]["name"]).to eq("Filter Test")
      end

      it "supports filtering by domain" do
        create(:tenant, domain: "filtertest.com")
        token = get_jwt_token(super_admin)
        
        get "#{api_path}?domain=filtertest.com", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json["data"].size).to eq(1)
        expect(json["data"][0]["domain"]).to eq("filtertest.com")
      end
    end

    describe "POST /api/v1/tenants" do
      it "creates a new tenant" do
        token = get_jwt_token(super_admin)
        
        post api_path, params: {
          tenant: {
            name: "API Tenant",
            domain: "apitenant.com",
            description: "Created via API"
          }
        }, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        
        expect(json["data"]["name"]).to eq("API Tenant")
        expect(json["data"]["domain"]).to eq("apitenant.com")
        expect(json["data"]["id"]).to be_present
      end

      it "returns validation errors" do
        token = get_jwt_token(super_admin)
        
        post api_path, params: {
          tenant: {
            name: "",
            domain: "invalid"
          }
        }, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        
        expect(json["errors"]["name"]).to include("can't be blank")
        expect(json["errors"]["domain"]).to include("is invalid")
      end

      it "prevents duplicate domains" do
        existing_tenant = create(:tenant, domain: "taken.com")
        token = get_jwt_token(super_admin)
        
        post api_path, params: {
          tenant: {
            name: "Duplicate",
            domain: "taken.com"
          }
        }, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        
        expect(json["errors"]["domain"]).to include("has already been taken")
      end
    end

    describe "GET /api/v1/tenants/:id" do
      it "returns tenant details" do
        token = get_jwt_token(super_admin)
        
        get "#{api_path}/#{tenant.id}", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json["data"]["id"]).to eq(tenant.id.to_s)
        expect(json["data"]["name"]).to eq(tenant.name)
        expect(json["data"]["domain"]).to eq(tenant.domain)
      end

      it "returns 404 for non-existent tenant" do
        token = get_jwt_token(super_admin)
        
        get "#{api_path}/#{SecureRandom.uuid}", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:not_found)
      end

      it "returns 403 for unauthorized access" do
        token = get_jwt_token(tenant_admin)
        other_tenant = create(:tenant)
        
        get "#{api_path}/#{other_tenant.id}", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "PUT /api/v1/tenants/:id" do
      it "updates tenant information" do
        token = get_jwt_token(super_admin)
        
        put "#{api_path}/#{tenant.id}", params: {
          tenant: {
            name: "Updated Name",
            description: "Updated description"
          }
        }, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json["data"]["name"]).to eq("Updated Name")
        expect(json["data"]["description"]).to eq("Updated description")
      end

      it "returns validation errors" do
        token = get_jwt_token(super_admin)
        
        put "#{api_path}/#{tenant.id}", params: {
          tenant: {
            name: ""
          }
        }, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        
        expect(json["errors"]["name"]).to include("can't be blank")
      end
    end

    describe "DELETE /api/v1/tenants/:id" do
      let!(:tenant_to_delete) { create(:tenant) }

      it "soft deletes tenant" do
        token = get_jwt_token(super_admin)
        
        delete "#{api_path}/#{tenant_to_delete.id}", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:no_content)
        
        expect(Tenant.with_deleted.find(tenant_to_delete.id)).to be_present
        expect(Tenant.find_by(id: tenant_to_delete.id)).to be_nil
      end

      it "prevents deletion of tenant with users" do
        create(:user, tenant: tenant_to_delete)
        token = get_jwt_token(super_admin)
        
        delete "#{api_path}/#{tenant_to_delete.id}", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        
        expect(json["error"]).to eq("cannot_delete_tenant_with_users")
      end

      it "force deletes tenant" do
        token = get_jwt_token(super_admin)
        
        delete "#{api_path}/#{tenant_to_delete.id}?force=true", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:no_content)
        
        expect(Tenant.with_deleted.find_by(id: tenant_to_delete.id)).to be_nil
      end
    end

    describe "PATCH /api/v1/tenants/:id/suspend" do
      it "suspends a tenant" do
        token = get_jwt_token(super_admin)
        
        patch "#{api_path}/#{tenant.id}/suspend", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        
        tenant.reload
        expect(tenant).to be_suspended
      end

      it "activates a suspended tenant" do
        tenant.suspend!
        token = get_jwt_token(super_admin)
        
        patch "#{api_path}/#{tenant.id}/activate", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        
        tenant.reload
        expect(tenant).not_to be_suspended
      end
    end
  end

  private

  def get_jwt_token(user)
    post "/api/v1/auth/login", params: {
      email: user.email,
      password: user.password
    }
    JSON.parse(response.body)["data"]["token"]
  end
end
