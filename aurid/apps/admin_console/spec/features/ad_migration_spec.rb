require 'rails_helper'

RSpec.describe "Active Directory Migration Features", type: :feature do
  let(:super_admin) { create(:user, :super_admin) }
  let(:tenant_admin) { create(:user, :tenant_admin) }
  let(:tenant) { tenant_admin.tenant }

  describe "AD Migration Setup" do
    before do
      sign_in super_admin
    end

    it "navigates to AD migration section" do
      visit root_path
      
      click_link "AD Migration"
      
      expect(page).to have_current_path(ad_migrations_path)
      expect(page).to have_content("Active Directory Migration")
    end

    it "creates a new AD migration project" do
      visit ad_migrations_path
      
      click_link "New Migration Project"
      
      fill_in "Project Name", with: "Company AD Migration"
      fill_in "Description", with: "Migrating from on-prem AD to Aurid"
      select tenant.name, from: "Target Tenant"
      fill_in "AD Domain", with: "company.local"
      fill_in "AD Server", with: "dc.company.local"
      fill_in "AD Port", with: "389"
      fill_in "Bind DN", with: "cn=admin,dc=company,dc=local"
      fill_in "Bind Password", with: "secure_password"
      check "Use SSL"
      
      click_button "Create Project"
      
      expect(page).to have_current_path(ad_migration_path(AdMigration.last))
      expect(page).to have_content("Migration project created successfully")
      expect(page).to have_content("Company AD Migration")
    end

    it "shows validation errors for invalid AD connection details" do
      visit new_ad_migration_path
      
      fill_in "Project Name", with: ""
      fill_in "AD Domain", with: ""
      fill_in "AD Server", with: "invalid server name"
      
      click_button "Create Project"
      
      expect(page).to have_current_path(ad_migrations_path)
      expect(page).to have_content("Project name can't be blank")
      expect(page).to have_content("AD domain can't be blank")
      expect(page).to have_content("AD server is invalid")
    end

    it "tests AD connection before creating project" do
      visit new_ad_migration_path
      
      fill_in "Project Name", with: "Test Connection"
      fill_in "AD Domain", with: "test.local"
      fill_in "AD Server", with: "dc.test.local"
      fill_in "AD Port", with: "389"
      fill_in "Bind DN", with: "cn=admin,dc=test,dc=local"
      fill_in "Bind Password", with: "password"
      
      click_button "Test Connection"
      
      # This would normally make an actual LDAP connection
      # For testing, we'll mock the response
      expect(page).to have_content("Connection test")
    end
  end

  describe "AD Migration Project Management" do
    let(:migration_project) { create(:ad_migration, name: "Test Migration", tenant: tenant) }

    before do
      sign_in super_admin
    end

    it "views migration project details" do
      visit ad_migration_path(migration_project)
      
      expect(page).to have_content("Test Migration")
      expect(page).to have_content("Status")
      expect(page).to have_content("Progress")
      expect(page).to have_content("AD Connection Details")
    end

    it "edits migration project settings" do
      visit edit_ad_migration_path(migration_project)
      
      fill_in "Project Name", with: "Updated Migration"
      fill_in "Description", with: "Updated description"
      fill_in "AD Server", with: "updated.dc.local"
      
      click_button "Update Project"
      
      expect(page).to have_current_path(ad_migration_path(migration_project))
      expect(page).to have_content("Migration project updated successfully")
      expect(page).to have_content("Updated Migration")
    end

    it "deletes migration project" do
      visit ad_migration_path(migration_project)
      
      accept_confirm do
        click_link "Delete Project"
      end
      
      expect(page).to have_current_path(ad_migrations_path)
      expect(page).to have_content("Migration project deleted successfully")
      expect(page).not_to have_content("Test Migration")
    end

    it "shows migration project status" do
      migration_project.update!(status: "in_progress", progress: 50)
      
      visit ad_migration_path(migration_project)
      
      expect(page).to have_content("In Progress")
      expect(page).to have_content("50%")
      expect(page).to have_selector(".progress-bar")
    end

    it "shows migration statistics" do
      migration_project.update!(
        users_migrated: 100,
        users_failed: 5,
        groups_migrated: 20,
        groups_failed: 2,
        start_time: 1.hour.ago,
        end_time: Time.current
      )
      
      visit ad_migration_path(migration_project)
      
      expect(page).to have_content("100 users migrated")
      expect(page).to have_content("5 users failed")
      expect(page).to have_content("20 groups migrated")
      expect(page).to have_content("2 groups failed")
      expect(page).to have_content("Duration")
    end
  end

  describe "AD User Discovery" do
    let(:migration_project) { create(:ad_migration, tenant: tenant) }

    before do
      sign_in super_admin
    end

    it "discovers AD users" do
      visit ad_migration_path(migration_project)
      
      click_link "Discover Users"
      
      # Mock AD user discovery
      # In a real scenario, this would connect to AD and fetch users
      expect(page).to have_content("Discovering users from Active Directory")
      
      # After discovery completes
      expect(page).to have_content("User discovery completed")
      expect(page).to have_selector(".ad-user")
    end

    it "filters discovered users" do
      # First discover users
      create_list(:ad_user, 10, migration: migration_project)
      
      visit ad_migration_path(migration_project)
      
      fill_in "Search Users", with: "admin"
      click_button "Search"
      
      expect(page).to have_selector(".ad-user", count: 1)
    end

    it "selects users for migration" do
      create_list(:ad_user, 5, migration: migration_project)
      
      visit ad_migration_path(migration_project)
      
      # Select first 3 users
      all(".ad-user input[type='checkbox']", minimum: 3).each do |checkbox|
        checkbox.check
      end
      
      click_button "Select for Migration"
      
      expect(page).to have_content("3 users selected for migration")
    end

    it "views user details from AD" do
      ad_user = create(:ad_user, 
        migration: migration_project,
        username: "jdoe",
        first_name: "John",
        last_name: "Doe",
        email: "jdoe@company.local",
        distinguished_name: "CN=John Doe,OU=Users,DC=company,DC=local"
      )
      
      visit ad_migration_path(migration_project)
      
      click_link "jdoe"
      
      expect(page).to have_content("John Doe")
      expect(page).to have_content("jdoe@company.local")
      expect(page).to have_content("CN=John Doe,OU=Users,DC=company,DC=local")
      expect(page).to have_content("AD Attributes")
    end

    it "maps AD attributes to Aurid user fields" do
      visit ad_migration_path(migration_project)
      
      click_link "Attribute Mapping"
      
      expect(page).to have_content("Attribute Mapping")
      
      # Map AD attributes to Aurid fields
      select "email", from: "userPrincipalName"
      select "first_name", from: "givenName"
      select "last_name", from: "sn"
      select "username", from: "sAMAccountName"
      
      click_button "Save Mapping"
      
      expect(page).to have_content("Attribute mapping saved successfully")
    end
  end

  describe "AD Group Discovery" do
    let(:migration_project) { create(:ad_migration, tenant: tenant) }

    before do
      sign_in super_admin
    end

    it "discovers AD groups" do
      visit ad_migration_path(migration_project)
      
      click_link "Discover Groups"
      
      expect(page).to have_content("Discovering groups from Active Directory")
      
      # After discovery completes
      expect(page).to have_content("Group discovery completed")
      expect(page).to have_selector(".ad-group")
    end

    it "filters discovered groups" do
      create_list(:ad_group, 10, migration: migration_project)
      
      visit ad_migration_path(migration_project)
      
      fill_in "Search Groups", with: "Admin"
      click_button "Search"
      
      expect(page).to have_selector(".ad-group", count: 1)
    end

    it "selects groups for migration" do
      create_list(:ad_group, 5, migration: migration_project)
      
      visit ad_migration_path(migration_project)
      
      # Select first 3 groups
      all(".ad-group input[type='checkbox']", minimum: 3).each do |checkbox|
        checkbox.check
      end
      
      click_button "Select for Migration"
      
      expect(page).to have_content("3 groups selected for migration")
    end

    it "views group details from AD" do
      ad_group = create(:ad_group,
        migration: migration_project,
        name: "Domain Admins",
        distinguished_name: "CN=Domain Admins,CN=Users,DC=company,DC=local",
        description: "Domain administrators group"
      )
      
      visit ad_migration_path(migration_project)
      
      click_link "Domain Admins"
      
      expect(page).to have_content("Domain Admins")
      expect(page).to have_content("CN=Domain Admins,CN=Users,DC=company,DC=local")
      expect(page).to have_content("Domain administrators group")
      expect(page).to have_content("Group Members")
    end

    it "maps AD groups to Aurid roles" do
      visit ad_migration_path(migration_project)
      
      click_link "Group Role Mapping"
      
      expect(page).to have_content("Group Role Mapping")
      
      # Map AD groups to Aurid roles
      fill_in "Domain Admins", with: "admin"
      fill_in "IT Staff", with: "tenant_admin"
      fill_in "Users", with: "tenant_user"
      
      click_button "Save Mapping"
      
      expect(page).to have_content("Group role mapping saved successfully")
    end
  end

  describe "AD Migration Execution" do
    let(:migration_project) { create(:ad_migration, tenant: tenant) }

    before do
      sign_in super_admin
      create_list(:ad_user, 5, migration: migration_project, selected: true)
      create_list(:ad_group, 3, migration: migration_project, selected: true)
    end

    it "starts migration process" do
      visit ad_migration_path(migration_project)
      
      click_button "Start Migration"
      
      expect(page).to have_content("Migration started successfully")
      
      migration_project.reload
      expect(migration_project.status).to eq("in_progress")
      expect(migration_project.start_time).to be_present
    end

    it "shows migration progress" do
      migration_project.update!(status: "in_progress", progress: 30)
      
      visit ad_migration_path(migration_project)
      
      expect(page).to have_content("Migration in progress")
      expect(page).to have_content("30%")
      expect(page).to have_selector(".progress-bar")
    end

    it "pauses migration process" do
      migration_project.update!(status: "in_progress")
      
      visit ad_migration_path(migration_project)
      
      click_button "Pause Migration"
      
      expect(page).to have_content("Migration paused successfully")
      
      migration_project.reload
      expect(migration_project.status).to eq("paused")
    end

    it "resumes paused migration" do
      migration_project.update!(status: "paused")
      
      visit ad_migration_path(migration_project)
      
      click_button "Resume Migration"
      
      expect(page).to have_content("Migration resumed successfully")
      
      migration_project.reload
      expect(migration_project.status).to eq("in_progress")
    end

    it "cancels migration process" do
      migration_project.update!(status: "in_progress")
      
      visit ad_migration_path(migration_project)
      
      accept_confirm do
        click_button "Cancel Migration"
      end
      
      expect(page).to have_content("Migration cancelled successfully")
      
      migration_project.reload
      expect(migration_project.status).to eq("cancelled")
    end

    it "completes migration successfully" do
      migration_project.update!(status: "completed", progress: 100)
      
      visit ad_migration_path(migration_project)
      
      expect(page).to have_content("Migration completed successfully")
      expect(page).to have_content("100%")
      expect(page).to have_content("Migration Summary")
    end

    it "handles migration failures" do
      migration_project.update!(
        status: "failed",
        progress: 75,
        error_message: "Connection to AD server lost"
      )
      
      visit ad_migration_path(migration_project)
      
      expect(page).to have_content("Migration failed")
      expect(page).to have_content("Connection to AD server lost")
      expect(page).to have_button("Retry Migration")
    end

    it "retries failed migration" do
      migration_project.update!(
        status: "failed",
        error_message: "Connection timeout"
      )
      
      visit ad_migration_path(migration_project)
      
      click_button "Retry Migration"
      
      expect(page).to have_content("Migration retry started successfully")
      
      migration_project.reload
      expect(migration_project.status).to eq("in_progress")
      expect(migration_project.error_message).to be_nil
    end
  end

  describe "AD Migration Results" do
    let(:migration_project) { create(:ad_migration, tenant: tenant) }

    before do
      sign_in super_admin
      
      # Create migration results
      create_list(:ad_user_result, 10, migration: migration_project, status: "success")
      create_list(:ad_user_result, 2, migration: migration_project, status: "failed")
      create_list(:ad_group_result, 5, migration: migration_project, status: "success")
      create_list(:ad_group_result, 1, migration: migration_project, status: "failed")
    end

    it "views migration results summary" do
      visit ad_migration_path(migration_project)
      
      expect(page).to have_content("Migration Results")
      expect(page).to have_content("10 users migrated successfully")
      expect(page).to have_content("2 users failed")
      expect(page).to have_content("5 groups migrated successfully")
      expect(page).to have_content("1 group failed")
    end

    it "views successful user migrations" do
      visit ad_migration_path(migration_project)
      
      click_link "Successful Users"
      
      expect(page).to have_selector(".user-result.success", count: 10)
    end

    it "views failed user migrations" do
      visit ad_migration_path(migration_project)
      
      click_link "Failed Users"
      
      expect(page).to have_selector(".user-result.failed", count: 2)
      
      # Show error details
      expect(page).to have_content("Error Details")
    end

    it "views successful group migrations" do
      visit ad_migration_path(migration_project)
      
      click_link "Successful Groups"
      
      expect(page).to have_selector(".group-result.success", count: 5)
    end

    it "views failed group migrations" do
      visit ad_migration_path(migration_project)
      
      click_link "Failed Groups"
      
      expect(page).to have_selector(".group-result.failed", count: 1)
    end

    it "exports migration results" do
      visit ad_migration_path(migration_project)
      
      click_link "Export Results"
      
      expect(page).to have_http_status(:success)
      expect(response_headers["Content-Type"]).to include("text/csv")
      expect(response_headers["Content-Disposition"]).to include("attachment")
    end

    it "views detailed error for failed migration" do
      failed_result = create(:ad_user_result,
        migration: migration_project,
        ad_user: create(:ad_user, migration: migration_project),
        status: "failed",
        error_message: "User already exists with this email",
        error_details: {
          field: "email",
          value: "existing@example.com",
          message: "Email has already been taken"
        }
      )
      
      visit ad_migration_path(migration_project)
      click_link "Failed Users"
      click_link failed_result.ad_user.username
      
      expect(page).to have_content("User already exists with this email")
      expect(page).to have_content("existing@example.com")
      expect(page).to have_content("Email has already been taken")
    end

    it "retrys failed user migration" do
      failed_result = create(:ad_user_result,
        migration: migration_project,
        ad_user: create(:ad_user, migration: migration_project),
        status: "failed",
        error_message: "Temporary connection issue"
      )
      
      visit ad_migration_path(migration_project)
      click_link "Failed Users"
      
      within("#user_result_#{failed_result.id}") do
        click_button "Retry"
      end
      
      expect(page).to have_content("Retrying migration for user")
      
      failed_result.reload
      expect(failed_result.status).to eq("pending")
    end
  end

  describe "AD Migration Scheduling" do
    let(:migration_project) { create(:ad_migration, tenant: tenant) }

    before do
      sign_in super_admin
    end

    it "schedules migration for later execution" do
      visit edit_ad_migration_path(migration_project)
      
      fill_in "Schedule Migration", with: "2024-12-25 14:00"
      
      click_button "Update Project"
      
      expect(page).to have_current_path(ad_migration_path(migration_project))
      
      migration_project.reload
      expect(migration_project.scheduled_at).to be_present
      expect(migration_project.status).to eq("scheduled")
    end

    it "shows scheduled migrations in calendar" do
      migration_project.update!(scheduled_at: 1.week.from_now)
      
      visit ad_migrations_path
      
      expect(page).to have_content("Scheduled Migrations")
      expect(page).to have_content(migration_project.name)
      expect(page).to have_content(migration_project.scheduled_at.strftime("%Y-%m-%d %H:%M"))
    end

    it "executes scheduled migration" do
      migration_project.update!(
        scheduled_at: 1.minute.ago,
        status: "scheduled"
      )
      
      # This would be triggered by a background job
      # For testing, we simulate the execution
      visit ad_migrations_path
      
      click_link "Run Scheduled Migrations"
      
      expect(page).to have_content("Scheduled migrations executed")
      
      migration_project.reload
      expect(migration_project.status).to eq("in_progress")
    end

    it "cancels scheduled migration" do
      migration_project.update!(
        scheduled_at: 1.hour.from_now,
        status: "scheduled"
      )
      
      visit ad_migration_path(migration_project)
      
      click_button "Cancel Schedule"
      
      expect(page).to have_content("Migration schedule cancelled")
      
      migration_project.reload
      expect(migration_project.scheduled_at).to be_nil
      expect(migration_project.status).to eq("pending")
    end
  end

  describe "AD Migration Templates" do
    before do
      sign_in super_admin
    end

    it "creates migration template from existing project" do
      migration_project = create(:ad_migration, 
        name: "Template Source",
        tenant: tenant,
        ad_domain: "template.local",
        ad_server: "dc.template.local"
      )
      
      visit ad_migration_path(migration_project)
      
      click_link "Save as Template"
      
      fill_in "Template Name", with: "Standard AD Migration"
      fill_in "Description", with: "Template for standard AD migrations"
      
      click_button "Save Template"
      
      expect(page).to have_current_path(ad_migration_templates_path)
      expect(page).to have_content("Template created successfully")
      expect(page).to have_content("Standard AD Migration")
    end

    it "uses template for new migration project" do
      template = create(:ad_migration_template,
        name: "Standard Template",
        ad_domain: "template.local",
        ad_server: "dc.template.local",
        attribute_mapping: {
          "userPrincipalName" => "email",
          "givenName" => "first_name",
          "sn" => "last_name"
        }
      )
      
      visit new_ad_migration_path
      
      select "Standard Template", from: "Template"
      
      fill_in "Project Name", with: "From Template"
      select tenant.name, from: "Target Tenant"
      
      click_button "Create Project"
      
      expect(page).to have_current_path(ad_migration_path(AdMigration.last))
      
      migration = AdMigration.last
      expect(migration.name).to eq("From Template")
      expect(migration.ad_domain).to eq("template.local")
      expect(migration.ad_server).to eq("dc.template.local")
    end

    it "manages migration templates" do
      template = create(:ad_migration_template, name: "Test Template")
      
      visit ad_migration_templates_path
      
      expect(page).to have_content("Test Template")
      
      click_link "Edit"
      
      fill_in "Name", with: "Updated Template"
      click_button "Update Template"
      
      expect(page).to have_content("Template updated successfully")
      
      accept_confirm do
        click_link "Delete"
      end
      
      expect(page).to have_content("Template deleted successfully")
    end
  end

  describe "AD Migration Access Control" do
    let(:migration_project) { create(:ad_migration, tenant: tenant) }
    let(:other_tenant) { create(:tenant) }
    let(:other_migration) { create(:ad_migration, tenant: other_tenant) }

    context "as super admin" do
      before do
        sign_in super_admin
      end

      it "can access all migration projects" do
        visit ad_migrations_path
        
        expect(page).to have_content(migration_project.name)
        expect(page).to have_content(other_migration.name)
      end

      it "can edit any migration project" do
        visit edit_ad_migration_path(migration_project)
        
        expect(page).to have_http_status(:success)
      end

      it "can delete any migration project" do
        visit ad_migration_path(migration_project)
        
        expect(page).to have_link("Delete Project")
      end

      it "can start any migration" do
        visit ad_migration_path(migration_project)
        
        expect(page).to have_button("Start Migration")
      end
    end

    context "as tenant admin" do
      before do
        sign_in tenant_admin
      end

      it "can only see their own tenant's migration projects" do
        visit ad_migrations_path
        
        expect(page).to have_content(migration_project.name)
        expect(page).not_to have_content(other_migration.name)
      end

      it "can edit their own tenant's migration projects" do
        visit edit_ad_migration_path(migration_project)
        
        expect(page).to have_http_status(:success)
      end

      it "can delete their own tenant's migration projects" do
        visit ad_migration_path(migration_project)
        
        expect(page).to have_link("Delete Project")
      end

      it "can start their own tenant's migrations" do
        visit ad_migration_path(migration_project)
        
        expect(page).to have_button("Start Migration")
      end

      it "cannot access other tenants' migration projects" do
        visit ad_migration_path(other_migration)
        
        expect(page).to have_current_path(root_path)
        expect(page).to have_content("Not authorized")
      end
    end

    context "as regular user" do
      let(:regular_user) { create(:user, :tenant_user, tenant: tenant) }

      before do
        sign_in regular_user
      end

      it "cannot access AD migration section" do
        visit ad_migrations_path
        
        expect(page).to have_current_path(root_path)
        expect(page).to have_content("Not authorized")
      end

      it "cannot access migration project" do
        visit ad_migration_path(migration_project)
        
        expect(page).to have_current_path(root_path)
        expect(page).to have_content("Not authorized")
      end
    end
  end

  describe "AD Migration API Endpoints" do
    let(:migration_project) { create(:ad_migration, tenant: tenant) }
    let(:api_path) { "/api/v1/ad_migrations" }

    describe "GET /api/v1/ad_migrations" do
      it "returns list of migration projects for super admin" do
        token = get_jwt_token(super_admin)
        
        get api_path, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json["data"].size).to be >= 1
        expect(json["data"][0]["id"]).to eq(migration_project.id.to_s)
      end

      it "returns only own tenant's migrations for tenant admin" do
        token = get_jwt_token(tenant_admin)
        
        get api_path, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json["data"].size).to eq(1)
        expect(json["data"][0]["id"]).to eq(migration_project.id.to_s)
      end

      it "returns 403 for regular users" do
        user = create(:user, tenant: tenant)
        token = get_jwt_token(user)
        
        get api_path, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "POST /api/v1/ad_migrations" do
      it "creates a new migration project" do
        token = get_jwt_token(super_admin)
        
        post api_path, params: {
          ad_migration: {
            name: "API Migration",
            tenant_id: tenant.id,
            ad_domain: "api.local",
            ad_server: "dc.api.local",
            bind_dn: "cn=admin,dc=api,dc=local",
            bind_password: "password"
          }
        }, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        
        expect(json["data"]["name"]).to eq("API Migration")
        expect(json["data"]["ad_domain"]).to eq("api.local")
        expect(json["data"]["id"]).to be_present
      end

      it "returns validation errors" do
        token = get_jwt_token(super_admin)
        
        post api_path, params: {
          ad_migration: {
            name: "",
            ad_domain: ""
          }
        }, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        
        expect(json["errors"]["name"]).to include("can't be blank")
        expect(json["errors"]["ad_domain"]).to include("can't be blank")
      end
    end

    describe "GET /api/v1/ad_migrations/:id" do
      it "returns migration project details" do
        token = get_jwt_token(super_admin)
        
        get "#{api_path}/#{migration_project.id}", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json["data"]["id"]).to eq(migration_project.id.to_s)
        expect(json["data"]["name"]).to eq(migration_project.name)
        expect(json["data"]["status"]).to eq(migration_project.status)
      end

      it "returns 404 for non-existent project" do
        token = get_jwt_token(super_admin)
        
        get "#{api_path}/#{SecureRandom.uuid}", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:not_found)
      end

      it "returns 403 for unauthorized access" do
        token = get_jwt_token(tenant_admin)
        other_migration = create(:ad_migration, tenant: create(:tenant))
        
        get "#{api_path}/#{other_migration.id}", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "PUT /api/v1/ad_migrations/:id" do
      it "updates migration project" do
        token = get_jwt_token(super_admin)
        
        put "#{api_path}/#{migration_project.id}", params: {
          ad_migration: {
            name: "Updated Migration",
            description: "Updated description"
          }
        }, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json["data"]["name"]).to eq("Updated Migration")
        expect(json["data"]["description"]).to eq("Updated description")
      end

      it "returns 403 for unauthorized updates" do
        token = get_jwt_token(tenant_admin)
        other_migration = create(:ad_migration, tenant: create(:tenant))
        
        put "#{api_path}/#{other_migration.id}", params: {
          ad_migration: {
            name: "Updated"
          }
        }, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "DELETE /api/v1/ad_migrations/:id" do
      let!(:migration_to_delete) { create(:ad_migration, tenant: tenant) }

      it "deletes migration project" do
        token = get_jwt_token(super_admin)
        
        delete "#{api_path}/#{migration_to_delete.id}", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:no_content)
        
        expect(AdMigration.find_by(id: migration_to_delete.id)).to be_nil
      end

      it "returns 403 for unauthorized deletion" do
        token = get_jwt_token(tenant_admin)
        other_migration = create(:ad_migration, tenant: create(:tenant))
        
        delete "#{api_path}/#{other_migration.id}", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "POST /api/v1/ad_migrations/:id/discover_users" do
      it "triggers user discovery" do
        token = get_jwt_token(super_admin)
        
        post "#{api_path}/#{migration_project.id}/discover_users", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:accepted)
        json = JSON.parse(response.body)
        
        expect(json["data"]["status"]).to eq("discovery_started")
        expect(json["data"]["message"]).to eq("User discovery started")
      end

      it "returns discovery results" do
        # Mock discovery results
        allow(AdMigrationService).to receive(:discover_users).and_return(
          OpenStruct.new(success?: true, users: [], message: "Discovery completed")
        )
        
        token = get_jwt_token(super_admin)
        
        post "#{api_path}/#{migration_project.id}/discover_users", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json["data"]["users"]).to be_present
      end
    end

    describe "POST /api/v1/ad_migrations/:id/discover_groups" do
      it "triggers group discovery" do
        token = get_jwt_token(super_admin)
        
        post "#{api_path}/#{migration_project.id}/discover_groups", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:accepted)
        json = JSON.parse(response.body)
        
        expect(json["data"]["status"]).to eq("discovery_started")
        expect(json["data"]["message"]).to eq("Group discovery started")
      end
    end

    describe "POST /api/v1/ad_migrations/:id/start" do
      it "starts migration" do
        token = get_jwt_token(super_admin)
        
        post "#{api_path}/#{migration_project.id}/start", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:accepted)
        json = JSON.parse(response.body)
        
        expect(json["data"]["status"]).to eq("migration_started")
        
        migration_project.reload
        expect(migration_project.status).to eq("in_progress")
      end

      it "returns 409 if migration already in progress" do
        migration_project.update!(status: "in_progress")
        token = get_jwt_token(super_admin)
        
        post "#{api_path}/#{migration_project.id}/start", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:conflict)
        json = JSON.parse(response.body)
        
        expect(json["error"]).to eq("migration_already_in_progress")
      end
    end

    describe "POST /api/v1/ad_migrations/:id/pause" do
      it "pauses migration" do
        migration_project.update!(status: "in_progress")
        token = get_jwt_token(super_admin)
        
        post "#{api_path}/#{migration_project.id}/pause", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        
        migration_project.reload
        expect(migration_project.status).to eq("paused")
      end
    end

    describe "POST /api/v1/ad_migrations/:id/resume" do
      it "resumes paused migration" do
        migration_project.update!(status: "paused")
        token = get_jwt_token(super_admin)
        
        post "#{api_path}/#{migration_project.id}/resume", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        
        migration_project.reload
        expect(migration_project.status).to eq("in_progress")
      end
    end

    describe "POST /api/v1/ad_migrations/:id/cancel" do
      it "cancels migration" do
        migration_project.update!(status: "in_progress")
        token = get_jwt_token(super_admin)
        
        post "#{api_path}/#{migration_project.id}/cancel", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        
        migration_project.reload
        expect(migration_project.status).to eq("cancelled")
      end
    end

    describe "GET /api/v1/ad_migrations/:id/status" do
      it "returns migration status" do
        token = get_jwt_token(super_admin)
        
        get "#{api_path}/#{migration_project.id}/status", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json["data"]["status"]).to eq(migration_project.status)
        expect(json["data"]["progress"]).to eq(migration_project.progress)
      end
    end

    describe "GET /api/v1/ad_migrations/:id/results" do
      it "returns migration results" do
        create_list(:ad_user_result, 5, migration: migration_project, status: "success")
        create_list(:ad_user_result, 2, migration: migration_project, status: "failed")
        
        token = get_jwt_token(super_admin)
        
        get "#{api_path}/#{migration_project.id}/results", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json["data"]["total_users"]).to eq(7)
        expect(json["data"]["successful_users"]).to eq(5)
        expect(json["data"]["failed_users"]).to eq(2)
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
