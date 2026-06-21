require 'rails_helper'

RSpec.describe "Authentication Features", type: :feature do
  let(:tenant) { create(:tenant) }
  let(:admin_user) { create(:user, :admin, tenant: tenant) }
  let(:regular_user) { create(:user, tenant: tenant) }

  describe "Web Authentication" do
    before do
      # Ensure Devise routes are available
      Rails.application.routes.draw do
        devise_for :users, controllers: {
          sessions: 'devise/sessions',
          passwords: 'devise/passwords',
          registrations: 'devise/registrations'
        }
      end
    end

    describe "Login Flow" do
      context "with valid credentials" do
        it "allows user to login and redirects to dashboard" do
          visit new_user_session_path
          
          fill_in "Email", with: admin_user.email
          fill_in "Password", with: admin_user.password
          click_button "Log in"
          
          expect(page).to have_current_path(dashboard_path)
          expect(page).to have_content("Signed in successfully")
          expect(page).to have_content(admin_user.email)
        end

        it "remembers the user when 'Remember me' is checked" do
          visit new_user_session_path
          
          fill_in "Email", with: admin_user.email
          fill_in "Password", with: admin_user.password
          check "Remember me"
          click_button "Log in"
          
          expect(page).to have_cookie("remember_user_token")
        end
      end

      context "with invalid credentials" do
        it "shows error message for wrong password" do
          visit new_user_session_path
          
          fill_in "Email", with: admin_user.email
          fill_in "Password", with: "wrong_password"
          click_button "Log in"
          
          expect(page).to have_current_path(new_user_session_path)
          expect(page).to have_content("Invalid Email or password")
        end

        it "shows error message for non-existent email" do
          visit new_user_session_path
          
          fill_in "Email", with: "nonexistent@example.com"
          fill_in "Password", with: "some_password"
          click_button "Log in"
          
          expect(page).to have_current_path(new_user_session_path)
          expect(page).to have_content("Invalid Email or password")
        end

        it "shows error message for empty credentials" do
          visit new_user_session_path
          click_button "Log in"
          
          expect(page).to have_current_path(new_user_session_path)
          expect(page).to have_content("Invalid Email or password")
        end
      end

      context "with locked account" do
        let(:locked_user) { create(:user, :locked, tenant: tenant) }

        it "shows account locked message" do
          visit new_user_session_path
          
          fill_in "Email", with: locked_user.email
          fill_in "Password", with: locked_user.password
          click_button "Log in"
          
          expect(page).to have_current_path(new_user_session_path)
          expect(page).to have_content("Your account is locked")
        end
      end
    end

    describe "Logout Flow" do
      before do
        sign_in admin_user
        visit dashboard_path
      end

      it "allows user to logout" do
        click_link "Logout"
        
        expect(page).to have_current_path(root_path)
        expect(page).to have_content("Signed out successfully")
      end

      it "clears the session after logout" do
        click_link "Logout"
        visit dashboard_path
        
        expect(page).to have_current_path(new_user_session_path)
        expect(page).to have_content("You need to sign in")
      end
    end

    describe "Password Reset Flow" do
      it "sends password reset instructions" do
        visit new_user_password_path
        
        fill_in "Email", with: admin_user.email
        click_button "Send me reset password instructions"
        
        expect(page).to have_current_path(root_path)
        expect(page).to have_content("You will receive an email")
        expect(ActionMailer::Base.deliveries.size).to eq(1)
      end

      it "shows error for non-existent email" do
        visit new_user_password_path
        
        fill_in "Email", with: "nonexistent@example.com"
        click_button "Send me reset password instructions"
        
        expect(page).to have_current_path(user_password_path)
        expect(page).to have_content("Email not found")
      end
    end

    describe "Session Management" do
      it "times out after inactivity" do
        sign_in admin_user
        visit dashboard_path
        
        # Simulate session timeout
        travel_to 1.hour.from_now do
          visit dashboard_path
          expect(page).to have_current_path(new_user_session_path)
        end
      end

      it "allows concurrent sessions" do
        # This tests that multiple devices can be logged in simultaneously
        sign_in admin_user
        
        # Open another browser session
        using_session("another browser") do
          sign_in admin_user
          expect(page).to have_content(admin_user.email)
        end
        
        # Original session should still be active
        expect(page).to have_content(admin_user.email)
      end
    end
  end

  describe "API Authentication" do
    let(:api_path) { "/api/v1/auth/login" }

    describe "JWT Login" do
      context "with valid credentials" do
        it "returns JWT token and user info" do
          post api_path, params: {
            email: admin_user.email,
            password: admin_user.password
          }
          
          expect(response).to have_http_status(:success)
          json = JSON.parse(response.body)
          
          expect(json["data"]["token"]).to be_present
          expect(json["data"]["user"]["email"]).to eq(admin_user.email)
          expect(json["data"]["user"]["id"]).to eq(admin_user.id.to_s)
        end

        it "returns refresh token" do
          post api_path, params: {
            email: admin_user.email,
            password: admin_user.password
          }
          
          json = JSON.parse(response.body)
          expect(json["data"]["refresh_token"]).to be_present
        end
      end

      context "with invalid credentials" do
        it "returns unauthorized for wrong password" do
          post api_path, params: {
            email: admin_user.email,
            password: "wrong_password"
          }
          
          expect(response).to have_http_status(:unauthorized)
          json = JSON.parse(response.body)
          expect(json["error"]).to eq("invalid_credentials")
        end

        it "returns unprocessable entity for missing credentials" do
          post api_path, params: {}
          
          expect(response).to have_http_status(:unprocessable_entity)
          json = JSON.parse(response.body)
          expect(json["error"]).to eq("invalid_credentials")
        end
      end

      context "with locked account" do
        let(:locked_user) { create(:user, :locked, tenant: tenant) }

        it "returns account locked error" do
          post api_path, params: {
            email: locked_user.email,
            password: locked_user.password
          }
          
          expect(response).to have_http_status(:locked)
          json = JSON.parse(response.body)
          expect(json["error"]).to eq("account_locked")
        end
      end
    end

    describe "JWT Token Refresh" do
      let(:refresh_path) { "/api/v1/auth/refresh" }

      it "returns new access token with valid refresh token" do
        # First, get tokens
        post api_path, params: {
          email: admin_user.email,
          password: admin_user.password
        }
        
        refresh_token = JSON.parse(response.body)["data"]["refresh_token"]
        
        # Then refresh
        post refresh_path, params: {
          refresh_token: refresh_token
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json["data"]["token"]).to be_present
        expect(json["data"]["token"]).not_to eq(refresh_token)
      end

      it "returns unauthorized with invalid refresh token" do
        post refresh_path, params: {
          refresh_token: "invalid_token"
        }
        
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns unauthorized with expired refresh token" do
        # Create an expired refresh token
        expired_token = JWT.encode(
          { user_id: admin_user.id, exp: 1.hour.ago.to_i },
          Rails.application.credentials.secret_key_base,
          'HS256'
        )
        
        post refresh_path, params: {
          refresh_token: expired_token
        }
        
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "JWT Token Validation" do
      let(:validate_path) { "/api/v1/auth/validate" }

      it "validates valid token" do
        post api_path, params: {
          email: admin_user.email,
          password: admin_user.password
        }
        
        token = JSON.parse(response.body)["data"]["token"]
        
        get validate_path, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["data"]["valid"]).to be true
      end

      it "rejects invalid token" do
        get validate_path, headers: {
          "Authorization" => "Bearer invalid_token"
        }
        
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects expired token" do
        expired_token = JWT.encode(
          { user_id: admin_user.id, exp: 1.hour.ago.to_i },
          Rails.application.credentials.secret_key_base,
          'HS256'
        )
        
        get validate_path, headers: {
          "Authorization" => "Bearer #{expired_token}"
        }
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "Multi-Factor Authentication" do
    let(:mfa_user) { create(:user, :with_mfa, tenant: tenant) }

    describe "Web MFA Flow" do
      it "requires OTP after password for MFA-enabled users" do
        visit new_user_session_path
        
        fill_in "Email", with: mfa_user.email
        fill_in "Password", with: mfa_user.password
        click_button "Log in"
        
        expect(page).to have_current_path(verify_otp_user_session_path)
        expect(page).to have_content("Two-factor authentication")
      end

      it "allows login with valid OTP" do
        visit new_user_session_path
        
        fill_in "Email", with: mfa_user.email
        fill_in "Password", with: mfa_user.password
        click_button "Log in"
        
        # Get OTP from user's backup codes or generate one
        otp = mfa_user.generate_otp_backup_code!
        
        fill_in "Code", with: otp
        click_button "Verify"
        
        expect(page).to have_current_path(dashboard_path)
        expect(page).to have_content("Signed in successfully")
      end

      it "rejects invalid OTP" do
        visit new_user_session_path
        
        fill_in "Email", with: mfa_user.email
        fill_in "Password", with: mfa_user.password
        click_button "Log in"
        
        fill_in "Code", with: "123456"
        click_button "Verify"
        
        expect(page).to have_current_path(verify_otp_user_session_path)
        expect(page).to have_content("Invalid code")
      end
    end

    describe "API MFA Flow" do
      let(:mfa_login_path) { "/api/v1/auth/login" }
      let(:mfa_verify_path) { "/api/v1/auth/verify_otp" }

      it "requires OTP for MFA-enabled users" do
        post mfa_login_path, params: {
          email: mfa_user.email,
          password: mfa_user.password
        }
        
        expect(response).to have_http_status(:multi_factor_authentication_required)
        json = JSON.parse(response.body)
        
        expect(json["data"]["mfa_required"]).to be true
        expect(json["data"]["session_token"]).to be_present
      end

      it "allows login with valid OTP" do
        # First step - login
        post mfa_login_path, params: {
          email: mfa_user.email,
          password: mfa_user.password
        }
        
        session_token = JSON.parse(response.body)["data"]["session_token"]
        otp = mfa_user.generate_otp_backup_code!
        
        # Second step - verify OTP
        post mfa_verify_path, params: {
          session_token: session_token,
          otp: otp
        }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["data"]["token"]).to be_present
      end
    end
  end

  describe "Role-Based Access Control" do
    let(:tenant_admin) { create(:user, :tenant_admin, tenant: tenant) }
    let(:tenant_user) { create(:user, :tenant_user, tenant: tenant) }

    describe "Web Access Control" do
      it "allows admin to access admin-only pages" do
        sign_in tenant_admin
        visit admin_dashboard_path
        
        expect(page).to have_http_status(:success)
        expect(page).to have_content("Admin Dashboard")
      end

      it "blocks non-admin users from admin pages" do
        sign_in tenant_user
        visit admin_dashboard_path
        
        expect(page).to have_current_path(root_path)
        expect(page).to have_content("You are not authorized")
      end

      it "shows appropriate navigation based on role" do
        sign_in tenant_admin
        visit dashboard_path
        
        expect(page).to have_link("Admin Dashboard")
        expect(page).to have_link("User Management")
        
        sign_out tenant_admin
        sign_in tenant_user
        visit dashboard_path
        
        expect(page).not_to have_link("Admin Dashboard")
        expect(page).not_to have_link("User Management")
      end
    end

    describe "API Access Control" do
      let(:admin_only_path) { "/api/v1/admin/users" }

      it "allows admin to access admin-only endpoints" do
        token = get_jwt_token(tenant_admin)
        
        get admin_only_path, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:success)
      end

      it "blocks non-admin users from admin-only endpoints" do
        token = get_jwt_token(tenant_user)
        
        get admin_only_path, headers: {
          "Authorization" => "Bearer #{token}"
        }
        
        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("forbidden")
      end
    end
  end

  describe "Tenant Isolation" do
    let(:tenant1) { create(:tenant) }
    let(:tenant2) { create(:tenant) }
    let(:user1) { create(:user, :admin, tenant: tenant1) }
    let(:user2) { create(:user, :admin, tenant: tenant2) }

    it "prevents cross-tenant access in web interface" do
      sign_in user1
      
      # Try to access tenant2's resources
      visit tenant_path(tenant2)
      
      expect(page).to have_current_path(root_path)
      expect(page).to have_content("Not authorized")
    end

    it "prevents cross-tenant access in API" do
      token = get_jwt_token(user1)
      
      get "/api/v1/tenants/#{tenant2.id}", headers: {
        "Authorization" => "Bearer #{token}"
      }
      
      expect(response).to have_http_status(:forbidden)
    end

    it "scopes data to current tenant" do
      sign_in user1
      
      # Create resources for both tenants
      tenant1_resource = create(:some_resource, tenant: tenant1)
      tenant2_resource = create(:some_resource, tenant: tenant2)
      
      visit resources_path
      
      expect(page).to have_content(tenant1_resource.name)
      expect(page).not_to have_content(tenant2_resource.name)
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

  def sign_in(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: user.password
    click_button "Log in"
  end

  def sign_out(user)
    click_link "Logout"
  end
end
