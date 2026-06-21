require 'rails_helper'

RSpec.describe "User Management Features", type: :feature do
  let(:super_admin) { create(:user, :super_admin) }
  let(:tenant_admin) { create(:user, :tenant_admin) }
  let(:tenant) { tenant_admin.tenant }

  describe "User CRUD Operations" do
    before do
      sign_in super_admin
    end

    describe "User Creation" do
      it "creates a new user with valid data" do
        visit new_user_path
        
        fill_in "Email", with: "newuser@example.com"
        fill_in "First Name", with: "John"
        fill_in "Last Name", with: "Doe"
        fill_in "Password", with: "password123"
        fill_in "Password Confirmation", with: "password123"
        select tenant.name, from: "Tenant"
        select "Tenant Admin", from: "Role"
        
        click_button "Create User"
        
        expect(page).to have_current_path(user_path(User.last))
        expect(page).to have_content("User created successfully")
        expect(page).to have_content("newuser@example.com")
        expect(page).to have_content("John Doe")
      end

      it "shows validation errors for invalid data" do
        visit new_user_path
        
        fill_in "Email", with: "invalid-email"
        fill_in "Password", with: "short"
        fill_in "Password Confirmation", with: "different"
        click_button "Create User"
        
        expect(page).to have_current_path(users_path)
        expect(page).to have_content("Email is invalid")
        expect(page).to have_content("Password is too short")
        expect(page).to have_content("Password confirmation doesn't match")
      end

      it "prevents duplicate email addresses" do
        existing_user = create(:user, email: "existing@example.com")
        
        visit new_user_path
        
        fill_in "Email", with: "existing@example.com"
        fill_in "Password", with: "password123"
        fill_in "Password Confirmation", with: "password123"
        click_button "Create User"
        
        expect(page).to have_current_path(users_path)
        expect(page).to have_content("Email has already been taken")
      end

      it "creates user with MFA enabled" do
        visit new_user_path
        
        fill_in "Email", with: "mfauser@example.com"
        fill_in "Password", with: "password123"
        fill_in "Password Confirmation", with: "password123"
        check "Enable MFA"
        
        click_button "Create User"
        
        expect(page).to have_current_path(user_path(User.last))
        user = User.last
        expect(user.mfa_enabled).to be true
      end

      it "creates user with custom preferences" do
        visit new_user_path
        
        fill_in "Email", with: "customuser@example.com"
        fill_in "Password", with: "password123"
        fill_in "Password Confirmation", with: "password123"
        select "German", from: "Language"
        select "Berlin", from: "Timezone"
        
        click_button "Create User"
        
        user = User.last
        expect(user.preferences["language"]).to eq("de")
        expect(user.preferences["timezone"]).to eq("Europe/Berlin")
      end
    end

    describe "User Viewing" do
      let!(:user1) { create(:user, email: "user1@example.com", first_name: "Alice", tenant: tenant) }
      let!(:user2) { create(:user, email: "user2@example.com", first_name: "Bob", tenant: tenant) }

      it "displays all users in a list" do
        visit users_path
        
        expect(page).to have_content("user1@example.com")
        expect(page).to have_content("Alice")
        expect(page).to have_content("user2@example.com")
        expect(page).to have_content("Bob")
      end

      it "shows user details" do
        visit user_path(user1)
        
        expect(page).to have_content("user1@example.com")
        expect(page).to have_content("Alice")
        expect(page).to have_content("Created at")
        expect(page).to have_content("Last sign in")
      end

      it "shows user roles and permissions" do
        visit user_path(user1)
        
        expect(page).to have_content("Roles")
        expect(page).to have_content("Permissions")
      end

      it "filters users by email" do
        visit users_path
        
        fill_in "Search", with: "user1@example.com"
        click_button "Search"
        
        expect(page).to have_content("user1@example.com")
        expect(page).not_to have_content("user2@example.com")
      end

      it "filters users by name" do
        visit users_path
        
        fill_in "Search", with: "Alice"
        click_button "Search"
        
        expect(page).to have_content("Alice")
        expect(page).not_to have_content("Bob")
      end

      it "filters users by tenant" do
        other_tenant = create(:tenant, name: "Other Tenant")
        other_user = create(:user, tenant: other_tenant)
        
        visit users_path
        
        select tenant.name, from: "Tenant"
        click_button "Filter"
        
        expect(page).to have_content("user1@example.com")
        expect(page).to have_content("user2@example.com")
        expect(page).not_to have_content(other_user.email)
      end

      it "filters users by role" do
        admin_user = create(:user, :admin, tenant: tenant)
        
        visit users_path
        
        select "Admin", from: "Role"
        click_button "Filter"
        
        expect(page).to have_content(admin_user.email)
        expect(page).not_to have_content(user1.email)
      end

      it "filters users by status" do
        locked_user = create(:user, :locked, tenant: tenant)
        
        visit users_path
        
        select "Locked", from: "Status"
        click_button "Filter"
        
        expect(page).to have_content(locked_user.email)
        expect(page).not_to have_content(user1.email)
      end

      it "paginates users" do
        create_list(:user, 25, tenant: tenant)
        
        visit users_path
        
        expect(page).to have_selector(".pagination")
        expect(page).to have_selector(".user-row", count: 20) # First page
      end
    end

    describe "User Editing" do
      let(:user) { create(:user, email: "editable@example.com", first_name: "Original", tenant: tenant) }

      it "updates user information" do
        visit edit_user_path(user)
        
        fill_in "First Name", with: "Updated"
        fill_in "Last Name", with: "Name"
        fill_in "Phone", with: "+1234567890"
        
        click_button "Update User"
        
        expect(page).to have_current_path(user_path(user))
        expect(page).to have_content("User updated successfully")
        expect(page).to have_content("Updated Name")
        expect(page).to have_content("+1234567890")
      end

      it "updates user email" do
        visit edit_user_path(user)
        
        fill_in "Email", with: "newemail@example.com"
        click_button "Update User"
        
        expect(page).to have_current_path(user_path(user))
        expect(page).to have_content("newemail@example.com")
      end

      it "updates user password" do
        visit edit_user_path(user)
        
        fill_in "New Password", with: "newpassword123"
        fill_in "New Password Confirmation", with: "newpassword123"
        click_button "Update User"
        
        expect(page).to have_current_path(user_path(user))
        expect(page).to have_content("User updated successfully")
      end

      it "updates user roles" do
        visit edit_user_path(user)
        
        select "Admin", from: "Role"
        click_button "Update User"
        
        user.reload
        expect(user).to have_role(:admin)
      end

      it "updates user tenant" do
        new_tenant = create(:tenant, name: "New Tenant")
        
        visit edit_user_path(user)
        
        select new_tenant.name, from: "Tenant"
        click_button "Update User"
        
        user.reload
        expect(user.tenant).to eq(new_tenant)
      end

      it "enables MFA for user" do
        visit edit_user_path(user)
        
        check "Enable MFA"
        click_button "Update User"
        
        user.reload
        expect(user.mfa_enabled).to be true
      end

      it "disables MFA for user" do
        user.update!(mfa_enabled: true)
        
        visit edit_user_path(user)
        
        uncheck "Enable MFA"
        click_button "Update User"
        
        user.reload
        expect(user.mfa_enabled).to be false
      end

      it "shows validation errors when updating" do
        visit edit_user_path(user)
        
        fill_in "Email", with: "invalid-email"
        click_button "Update User"
        
        expect(page).to have_current_path(user_path(user))
        expect(page).to have_content("Email is invalid")
      end

      it "prevents changing email to existing email" do
        existing_user = create(:user, email: "taken@example.com")
        
        visit edit_user_path(user)
        
        fill_in "Email", with: "taken@example.com"
        click_button "Update User"
        
        expect(page).to have_current_path(user_path(user))
        expect(page).to have_content("Email has already been taken")
      end
    end

    describe "User Deletion" do
      let!(:user) { create(:user, email: "to_delete@example.com", tenant: tenant) }

      it "deletes a user" do
        visit user_path(user)
        
        accept_confirm do
          click_link "Delete"
        end
        
        expect(page).to have_current_path(users_path)
        expect(page).to have_content("User deleted successfully")
        expect(page).not_to have_content("to_delete@example.com")
      end

      it "soft deletes user by default" do
        visit user_path(user)
        
        accept_confirm do
          click_link "Delete"
        end
        
        expect(User.with_deleted.find(user.id)).to be_present
        expect(User.find_by(id: user.id)).to be_nil
      end

      it "hard deletes user when forced" do
        visit user_path(user)
        
        accept_confirm do
          click_link "Force Delete"
        end
        
        expect(User.with_deleted.find_by(id: user.id)).to be_nil
      end

      it "prevents deletion of own account" do
        visit user_path(super_admin)
        
        expect(page).not_to have_link("Delete")
        expect(page).to have_content("Cannot delete your own account")
      end
    end
  end

  describe "User Status Management" do
    let(:user) { create(:user, tenant: tenant) }

    before do
      sign_in super_admin
    end

    it "locks a user" do
      visit user_path(user)
      
      click_link "Lock"
      
      expect(page).to have_current_path(user_path(user))
      expect(page).to have_content("User locked successfully")
      
      user.reload
      expect(user).to be_locked
    end

    it "unlocks a locked user" do
      user.lock!
      
      visit user_path(user)
      
      click_link "Unlock"
      
      expect(page).to have_current_path(user_path(user))
      expect(page).to have_content("User unlocked successfully")
      
      user.reload
      expect(user).not_to be_locked
    end

    it "suspends a user" do
      visit user_path(user)
      
      click_link "Suspend"
      
      expect(page).to have_current_path(user_path(user))
      expect(page).to have_content("User suspended successfully")
      
      user.reload
      expect(user).to be_suspended
    end

    it "activates a suspended user" do
      user.suspend!
      
      visit user_path(user)
      
      click_link "Activate"
      
      expect(page).to have_current_path(user_path(user))
      expect(page).to have_content("User activated successfully")
      
      user.reload
      expect(user).not_to be_suspended
    end

    it "shows status in user list" do
      locked_user = create(:user, :locked, tenant: tenant)
      suspended_user = create(:user, :suspended, tenant: tenant)
      
      visit users_path
      
      expect(page).to have_content("Active")
      expect(page).to have_selector(".status-locked")
      expect(page).to have_selector(".status-suspended")
    end

    it "prevents actions on locked users" do
      user.lock!
      
      visit edit_user_path(user)
      
      expect(page).to have_current_path(user_path(user))
      expect(page).to have_content("User is locked")
    end

    it "prevents actions on suspended users" do
      user.suspend!
      
      visit edit_user_path(user)
      
      expect(page).to have_current_path(user_path(user))
      expect(page).to have_content("User is suspended")
    end
  end

  describe "User Profile Management" do
    let(:user) { create(:user, tenant: tenant) }

    context "as the user themselves" do
      before do
        sign_in user
      end

      it "allows user to edit their own profile" do
        visit edit_profile_path
        
        fill_in "First Name", with: "Updated"
        fill_in "Last Name", with: "Name"
        fill_in "Phone", with: "+1234567890"
        
        click_button "Update Profile"
        
        expect(page).to have_current_path(profile_path)
        expect(page).to have_content("Profile updated successfully")
        expect(page).to have_content("Updated Name")
      end

      it "allows user to change their password" do
        visit edit_profile_path
        
        fill_in "Current Password", with: user.password
        fill_in "New Password", with: "newpassword123"
        fill_in "New Password Confirmation", with: "newpassword123"
        
        click_button "Update Password"
        
        expect(page).to have_current_path(profile_path)
        expect(page).to have_content("Password updated successfully")
      end

      it "allows user to manage their preferences" do
        visit edit_profile_path
        
        select "German", from: "Language"
        select "Berlin", from: "Timezone"
        check "Dark mode"
        
        click_button "Update Preferences"
        
        user.reload
        expect(user.preferences["language"]).to eq("de")
        expect(user.preferences["timezone"]).to eq("Europe/Berlin")
        expect(user.preferences["dark_mode"]).to be true
      end

      it "allows user to manage their MFA settings" do
        visit edit_profile_path
        
        click_link "Manage MFA"
        
        expect(page).to have_content("Two-Factor Authentication")
      end

      it "allows user to view their activity log" do
        visit profile_path
        
        click_link "Activity Log"
        
        expect(page).to have_content("Activity Log")
        expect(page).to have_selector(".activity-entry")
      end
    end

    context "as an admin" do
      before do
        sign_in super_admin
      end

      it "can view any user's profile" do
        visit user_path(user)
        
        expect(page).to have_http_status(:success)
        expect(page).to have_content(user.email)
      end

      it "can edit any user's profile" do
        visit edit_user_path(user)
        
        expect(page).to have_http_status(:success)
      end
    end
  end

  describe "User Access Control" do
    let(:tenant) { create(:tenant) }
    let(:tenant_admin) { create(:user, :tenant_admin, tenant: tenant) }
    let(:tenant_user) { create(:user, :tenant_user, tenant: tenant) }
    let(:other_tenant_user) { create(:user, tenant: create(:tenant)) }

    context "as super admin" do
      before do
        sign_in super_admin
      end

      it "can access all users" do
        visit users_path
        
        expect(page).to have_content(tenant_admin.email)
        expect(page).to have_content(tenant_user.email)
        expect(page).to have_content(other_tenant_user.email)
      end

      it "can edit any user" do
        visit edit_user_path(tenant_user)
        
        expect(page).to have_http_status(:success)
      end

      it "can delete any user" do
        visit user_path(tenant_user)
        
        expect(page).to have_link("Delete")
      end

      it "can change any user's role" do
        visit edit_user_path(tenant_user)
        
        select "Admin", from: "Role"
        click_button "Update User"
        
        expect(page).to have_current_path(user_path(tenant_user))
        tenant_user.reload
        expect(tenant_user).to have_role(:admin)
      end

      it "can change any user's tenant" do
        new_tenant = create(:tenant)
        
        visit edit_user_path(tenant_user)
        
        select new_tenant.name, from: "Tenant"
        click_button "Update User"
        
        tenant_user.reload
        expect(tenant_user.tenant).to eq(new_tenant)
      end
    end

    context "as tenant admin" do
      before do
        sign_in tenant_admin
      end

      it "can only see users in their own tenant" do
        visit users_path
        
        expect(page).to have_content(tenant_admin.email)
        expect(page).to have_content(tenant_user.email)
        expect(page).not_to have_content(other_tenant_user.email)
      end

      it "can edit users in their own tenant" do
        visit edit_user_path(tenant_user)
        
        expect(page).to have_http_status(:success)
      end

      it "can delete users in their own tenant" do
        visit user_path(tenant_user)
        
        expect(page).to have_link("Delete")
      end

      it "can change user roles within their tenant" do
        visit edit_user_path(tenant_user)
        
        select "Tenant Admin", from: "Role"
        click_button "Update User"
        
        tenant_user.reload
        expect(tenant_user).to have_role(:tenant_admin)
      end

      it "cannot change user's tenant" do
        visit edit_user_path(tenant_user)
        
        expect(page).not_to have_selector("select[name='user[tenant_id]']")
      end

      it "cannot access users from other tenants" do
        visit user_path(other_tenant_user)
        
        expect(page).to have_current_path(root_path)
        expect(page).to have_content("Not authorized")
      end

      it "cannot edit users from other tenants" do
        visit edit_user_path(other_tenant_user)
        
        expect(page).to have_current_path(root_path)
        expect(page).to have_content("Not authorized")
      end
    end

    context "as regular user" do
      before do
        sign_in tenant_user
      end

      it "can only see their own profile" do
        visit users_path
        
        expect(page).to have_current_path(root_path)
        expect(page).to have_content("Not authorized")
      end

      it "can access their own profile" do
        visit profile_path
        
        expect(page).to have_http_status(:success)
        expect(page).to have_content(tenant_user.email)
      end

      it "cannot access other users' profiles" do
        visit user_path(tenant_admin)
        
        expect(page).to have_current_path(root_path)
        expect(page).to have_content("Not authorized")
      end

      it "cannot access user management" do
        visit new_user_path
        
        expect(page).to have_current_path(root_path)
        expect(page).to have_content("Not authorized")
      end
    end
  end

  describe "User Bulk Operations" do
    let(:tenant) { create(:tenant) }

    before do
      sign_in super_admin
      create_list(:user, 10, tenant: tenant)
    end

    it "bulk imports users from CSV" do
      visit users_path
      
      click_link "Import"
      
      # Attach CSV file
      csv_content = "email,first_name,last_name,role\n"
      csv_content += "user1@import.com,John,Doe,tenant_user\n"
      csv_content += "user2@import.com,Jane,Smith,tenant_user\n"
      
      attach_file "CSV File", StringIO.new(csv_content), "text/csv"
      select tenant.name, from: "Tenant"
      
      click_button "Import"
      
      expect(page).to have_current_path(users_path)
      expect(page).to have_content("2 users imported successfully")
      
      expect(User.where(email: "user1@import.com").count).to eq(1)
      expect(User.where(email: "user2@import.com").count).to eq(1)
    end

    it "shows import errors" do
      visit users_path
      
      click_link "Import"
      
      # Invalid CSV
      csv_content = "email,first_name,last_name\n"
      csv_content += "invalid-email,John,Doe\n"
      
      attach_file "CSV File", StringIO.new(csv_content), "text/csv"
      
      click_button "Import"
      
      expect(page).to have_current_path(import_users_path)
      expect(page).to have_content("1 error")
      expect(page).to have_content("Email is invalid")
    end

    it "bulk exports users to CSV" do
      visit users_path
      
      click_link "Export"
      
      expect(page).to have_http_status(:success)
      expect(response_headers["Content-Type"]).to include("text/csv")
      expect(response_headers["Content-Disposition"]).to include("attachment")
    end

    it "bulk updates user roles" do
      users = User.where(tenant: tenant).limit(5)
      
      visit users_path
      
      users.each do |user|
        check "user_#{user.id}"
      end
      
      select "Tenant Admin", from: "Bulk Action"
      click_button "Apply"
      
      expect(page).to have_current_path(users_path)
      expect(page).to have_content("5 users updated successfully")
      
      users.each do |user|
        user.reload
        expect(user).to have_role(:tenant_admin)
      end
    end

    it "bulk locks users" do
      users = User.where(tenant: tenant).limit(3)
      
      visit users_path
      
      users.each do |user|
        check "user_#{user.id}"
      end
      
      select "Lock", from: "Bulk Action"
      click_button "Apply"
      
      expect(page).to have_current_path(users_path)
      expect(page).to have_content("3 users locked successfully")
      
      users.each do |user|
        user.reload
        expect(user).to be_locked
      end
    end

    it "bulk suspends users" do
      users = User.where(tenant: tenant).limit(2)
      
      visit users_path
      
      users.each do |user|
        check "user_#{user.id}"
      end
      
      select "Suspend", from: "Bulk Action"
      click_button "Apply"
      
      expect(page).to have_current_path(users_path)
      expect(page).to have_content("2 users suspended successfully")
      
      users.each do |user|
        user.reload
        expect(user).to be_suspended
      end
    end

    it "bulk deletes users" do
      users = User.where(tenant: tenant).limit(4)
      
      visit users_path
      
      users.each do |user|
        check "user_#{user.id}"
      end
      
      select "Delete", from: "Bulk Action"
      click_button "Apply"
      
      expect(page).to have_current_path(users_path)
      expect(page).to have_content("4 users deleted successfully")
      
      users.each do |user|
        expect(User.find_by(id: user.id)).to be_nil
      end
    end
  end

  describe "User API Endpoints" do
    let(:tenant) { create(:tenant) }
    let(:user) { create(:user, tenant: tenant) }
    let(:api_path) { "/api/v1/users" }

    describe "GET /api/v1/users" do
      it "returns list of users for super admin" do
        token = get_jwt_token(super_admin)
        
        get api_path, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json["data"].size).to be >= 1
        expect(json["data"][0]["id"]).to eq(user.id.to_s)
      end

      it "returns only tenant users for tenant admin" do
        token = get_jwt_token(tenant_admin)
        
        get api_path, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json["data"].size).to eq(1) # Only the tenant admin themselves
        expect(json["data"][0]["id"]).to eq(tenant_admin.id.to_s)
      end

      it "returns only own profile for regular user" do
        token = get_jwt_token(user)
        
        get api_path, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json["data"].size).to eq(1)
        expect(json["data"][0]["id"]).to eq(user.id.to_s)
      end

      it "supports pagination" do
        create_list(:user, 25, tenant: tenant)
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

      it "supports filtering by email" do
        create(:user, email: "filter@test.com", tenant: tenant)
        token = get_jwt_token(super_admin)
        
        get "#{api_path}?email=filter@test.com", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json["data"].size).to eq(1)
        expect(json["data"][0]["email"]).to eq("filter@test.com")
      end

      it "supports filtering by tenant" do
        other_tenant = create(:tenant)
        create(:user, tenant: other_tenant)
        token = get_jwt_token(super_admin)
        
        get "#{api_path}?tenant_id=#{tenant.id}", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json["data"].size).to eq(1)
        expect(json["data"][0]["tenant_id"]).to eq(tenant.id.to_s)
      end

      it "supports filtering by role" do
        create(:user, :admin, tenant: tenant)
        token = get_jwt_token(super_admin)
        
        get "#{api_path}?role=admin", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json["data"].size).to eq(1)
        expect(json["data"][0]["roles"]).to include("admin")
      end
    end

    describe "POST /api/v1/users" do
      it "creates a new user" do
        token = get_jwt_token(super_admin)
        
        post api_path, params: {
          user: {
            email: "apiuser@example.com",
            first_name: "API",
            last_name: "User",
            password: "password123",
            password_confirmation: "password123",
            tenant_id: tenant.id,
            role: "tenant_user"
          }
        }, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        
        expect(json["data"]["email"]).to eq("apiuser@example.com")
        expect(json["data"]["first_name"]).to eq("API")
        expect(json["data"]["last_name"]).to eq("User")
        expect(json["data"]["id"]).to be_present
      end

      it "returns validation errors" do
        token = get_jwt_token(super_admin)
        
        post api_path, params: {
          user: {
            email: "invalid",
            password: "short",
            password_confirmation: "different"
          }
        }, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        
        expect(json["errors"]["email"]).to include("is invalid")
        expect(json["errors"]["password"]).to include("is too short")
        expect(json["errors"]["password_confirmation"]).to include("doesn't match")
      end

      it "prevents duplicate emails" do
        existing_user = create(:user, email: "taken@example.com")
        token = get_jwt_token(super_admin)
        
        post api_path, params: {
          user: {
            email: "taken@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        
        expect(json["errors"]["email"]).to include("has already been taken")
      end
    end

    describe "GET /api/v1/users/:id" do
      it "returns user details" do
        token = get_jwt_token(super_admin)
        
        get "#{api_path}/#{user.id}", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json["data"]["id"]).to eq(user.id.to_s)
        expect(json["data"]["email"]).to eq(user.email)
      end

      it "returns 404 for non-existent user" do
        token = get_jwt_token(super_admin)
        
        get "#{api_path}/#{SecureRandom.uuid}", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:not_found)
      end

      it "returns 403 for unauthorized access" do
        other_user = create(:user, tenant: create(:tenant))
        token = get_jwt_token(user)
        
        get "#{api_path}/#{other_user.id}", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:forbidden)
      end

      it "allows user to access their own profile" do
        token = get_jwt_token(user)
        
        get "#{api_path}/#{user.id}", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
      end
    end

    describe "PUT /api/v1/users/:id" do
      it "updates user information" do
        token = get_jwt_token(super_admin)
        
        put "#{api_path}/#{user.id}", params: {
          user: {
            first_name: "Updated",
            last_name: "Name",
            phone: "+1234567890"
          }
        }, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json["data"]["first_name"]).to eq("Updated")
        expect(json["data"]["last_name"]).to eq("Name")
        expect(json["data"]["phone"]).to eq("+1234567890")
      end

      it "returns validation errors" do
        token = get_jwt_token(super_admin)
        
        put "#{api_path}/#{user.id}", params: {
          user: {
            email: "invalid"
          }
        }, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        
        expect(json["errors"]["email"]).to include("is invalid")
      end

      it "returns 403 for unauthorized updates" do
        other_user = create(:user, tenant: create(:tenant))
        token = get_jwt_token(user)
        
        put "#{api_path}/#{other_user.id}", params: {
          user: {
            first_name: "Updated"
          }
        }, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:forbidden)
      end

      it "allows user to update their own profile" do
        token = get_jwt_token(user)
        
        put "#{api_path}/#{user.id}", params: {
          user: {
            first_name: "Updated"
          }
        }, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
      end
    end

    describe "DELETE /api/v1/users/:id" do
      let!(:user_to_delete) { create(:user, tenant: tenant) }

      it "soft deletes user" do
        token = get_jwt_token(super_admin)
        
        delete "#{api_path}/#{user_to_delete.id}", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:no_content)
        
        expect(User.with_deleted.find(user_to_delete.id)).to be_present
        expect(User.find_by(id: user_to_delete.id)).to be_nil
      end

      it "prevents deletion of own account" do
        token = get_jwt_token(user)
        
        delete "#{api_path}/#{user.id}", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        
        expect(json["error"]).to eq("cannot_delete_own_account")
      end

      it "returns 403 for unauthorized deletion" do
        other_user = create(:user, tenant: create(:tenant))
        token = get_jwt_token(user)
        
        delete "#{api_path}/#{other_user.id}", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:forbidden)
      end

      it "force deletes user" do
        token = get_jwt_token(super_admin)
        
        delete "#{api_path}/#{user_to_delete.id}?force=true", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:no_content)
        
        expect(User.with_deleted.find_by(id: user_to_delete.id)).to be_nil
      end
    end

    describe "PATCH /api/v1/users/:id/lock" do
      it "locks a user" do
        token = get_jwt_token(super_admin)
        
        patch "#{api_path}/#{user.id}/lock", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        
        user.reload
        expect(user).to be_locked
      end

      it "unlocks a user" do
        user.lock!
        token = get_jwt_token(super_admin)
        
        patch "#{api_path}/#{user.id}/unlock", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        
        user.reload
        expect(user).not_to be_locked
      end

      it "returns 403 for unauthorized lock operations" do
        token = get_jwt_token(user)
        other_user = create(:user, tenant: create(:tenant))
        
        patch "#{api_path}/#{other_user.id}/lock", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "PATCH /api/v1/users/:id/suspend" do
      it "suspends a user" do
        token = get_jwt_token(super_admin)
        
        patch "#{api_path}/#{user.id}/suspend", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        
        user.reload
        expect(user).to be_suspended
      end

      it "activates a suspended user" do
        user.suspend!
        token = get_jwt_token(super_admin)
        
        patch "#{api_path}/#{user.id}/activate", headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        
        user.reload
        expect(user).not_to be_suspended
      end
    end

    describe "PATCH /api/v1/users/:id/add_role" do
      it "adds a role to user" do
        token = get_jwt_token(super_admin)
        
        patch "#{api_path}/#{user.id}/add_role", params: {
          role: "admin"
        }, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        
        user.reload
        expect(user).to have_role(:admin)
      end

      it "returns 403 for unauthorized role addition" do
        token = get_jwt_token(user)
        other_user = create(:user, tenant: create(:tenant))
        
        patch "#{api_path}/#{other_user.id}/add_role", params: {
          role: "admin"
        }, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "PATCH /api/v1/users/:id/remove_role" do
      it "removes a role from user" do
        user.add_role(:admin)
        token = get_jwt_token(super_admin)
        
        patch "#{api_path}/#{user.id}/remove_role", params: {
          role: "admin"
        }, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        
        user.reload
        expect(user).not_to have_role(:admin)
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
