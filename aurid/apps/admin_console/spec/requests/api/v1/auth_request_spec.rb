require 'rails_helper'

RSpec.describe "API V1 Auth Requests", type: :request do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, :with_password, tenant: tenant, password: 'password123') }
  let(:headers) { { "Content-Type" => "application/json" } }

  describe "POST /api/v1/auth/login" do
    let(:path) { "/api/v1/auth/login" }

    context "with valid credentials" do
      let(:params) do
        {
          email: user.email,
          password: 'password123'
        }
      end

      it "returns HTTP success" do
        post path, params: params.to_json, headers: headers
        expect(response).to have_http_status(:success)
      end

      it "returns JWT token" do
        post path, params: params.to_json, headers: headers
        json = JSON.parse(response.body)
        expect(json["data"]["token"]).to be_present
      end

      it "returns refresh token" do
        post path, params: params.to_json, headers: headers
        json = JSON.parse(response.body)
        expect(json["data"]["refresh_token"]).to be_present
      end

      it "returns user information" do
        post path, params: params.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json["data"]["user"]["id"]).to eq(user.id.to_s)
        expect(json["data"]["user"]["email"]).to eq(user.email)
        expect(json["data"]["user"]["first_name"]).to eq(user.first_name)
        expect(json["data"]["user"]["last_name"]).to eq(user.last_name)
      end

      it "returns user roles" do
        post path, params: params.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json["data"]["user"]["roles"]).to be_present
      end

      it "returns tenant information" do
        post path, params: params.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json["data"]["user"]["tenant_id"]).to eq(tenant.id.to_s)
        expect(json["data"]["user"]["tenant_name"]).to eq(tenant.name)
      end

      it "returns response metadata" do
        post path, params: params.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json["meta"]["status"]).to eq("success")
        expect(json["meta"]["timestamp"]).to be_present
      end
    end

    context "with invalid credentials" do
      it "returns HTTP unauthorized for wrong password" do
        post path, params: { email: user.email, password: 'wrong_password' }.to_json, headers: headers
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns HTTP unauthorized for non-existent email" do
        post path, params: { email: 'nonexistent@example.com', password: 'password123' }.to_json, headers: headers
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns error details for invalid credentials" do
        post path, params: { email: user.email, password: 'wrong_password' }.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json["error"]).to eq("invalid_credentials")
        expect(json["message"]).to eq("Invalid email or password")
        expect(json["status"]).to eq("unauthorized")
      end
    end

    context "with missing credentials" do
      it "returns HTTP unprocessable entity for missing email" do
        post path, params: { password: 'password123' }.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns HTTP unprocessable entity for missing password" do
        post path, params: { email: user.email }.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns HTTP unprocessable entity for empty credentials" do
        post path, params: {}.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns error details for missing credentials" do
        post path, params: {}.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json["error"]).to eq("invalid_credentials")
        expect(json["message"]).to eq("Email and password are required")
      end
    end

    context "with locked account" do
      let(:locked_user) { create(:user, :locked, :with_password, tenant: tenant, password: 'password123') }

      it "returns HTTP locked" do
        post path, params: { email: locked_user.email, password: 'password123' }.to_json, headers: headers
        expect(response).to have_http_status(:locked)
      end

      it "returns account locked error" do
        post path, params: { email: locked_user.email, password: 'password123' }.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json["error"]).to eq("account_locked")
        expect(json["message"]).to eq("Your account is locked")
      end
    end

    context "with suspended account" do
      let(:suspended_user) { create(:user, :suspended, :with_password, tenant: tenant, password: 'password123') }

      it "returns HTTP forbidden" do
        post path, params: { email: suspended_user.email, password: 'password123' }.to_json, headers: headers
        expect(response).to have_http_status(:forbidden)
      end

      it "returns account suspended error" do
        post path, params: { email: suspended_user.email, password: 'password123' }.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json["error"]).to eq("account_suspended")
        expect(json["message"]).to eq("Your account is suspended")
      end
    end

    context "with MFA enabled user" do
      let(:mfa_user) { create(:user, :with_mfa, :with_password, tenant: tenant, password: 'password123') }

      it "returns HTTP multi_factor_authentication_required" do
        post path, params: { email: mfa_user.email, password: 'password123' }.to_json, headers: headers
        expect(response).to have_http_status(:multi_factor_authentication_required)
      end

      it "returns MFA required response" do
        post path, params: { email: mfa_user.email, password: 'password123' }.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json["data"]["mfa_required"]).to be true
        expect(json["data"]["session_token"]).to be_present
        expect(json["data"]["mfa_type"]).to eq("totp")
      end
    end

    context "with rate limiting" do
      it "limits login attempts" do
        # Make multiple failed attempts
        5.times do
          post path, params: { email: user.email, password: 'wrong_password' }.to_json, headers: headers
        end
        
        # Next attempt should be rate limited
        post path, params: { email: user.email, password: 'password123' }.to_json, headers: headers
        
        expect(response).to have_http_status(:too_many_requests)
      end

      it "returns rate limit error" do
        5.times do
          post path, params: { email: user.email, password: 'wrong_password' }.to_json, headers: headers
        end
        
        post path, params: { email: user.email, password: 'password123' }.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json["error"]).to eq("rate_limit_exceeded")
        expect(json["message"]).to include("Too many requests")
      end
    end
  end

  describe "POST /api/v1/auth/refresh" do
    let(:path) { "/api/v1/auth/refresh" }

    context "with valid refresh token" do
      it "returns HTTP success" do
        # First, get tokens
        post "/api/v1/auth/login", params: { email: user.email, password: 'password123' }.to_json, headers: headers
        refresh_token = JSON.parse(response.body)["data"]["refresh_token"]
        
        # Then refresh
        post path, params: { refresh_token: refresh_token }.to_json, headers: headers
        expect(response).to have_http_status(:success)
      end

      it "returns new access token" do
        post "/api/v1/auth/login", params: { email: user.email, password: 'password123' }.to_json, headers: headers
        refresh_token = JSON.parse(response.body)["data"]["refresh_token"]
        
        post path, params: { refresh_token: refresh_token }.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json["data"]["token"]).to be_present
      end

      it "returns new refresh token" do
        post "/api/v1/auth/login", params: { email: user.email, password: 'password123' }.to_json, headers: headers
        refresh_token = JSON.parse(response.body)["data"]["refresh_token"]
        
        post path, params: { refresh_token: refresh_token }.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json["data"]["refresh_token"]).to be_present
        expect(json["data"]["refresh_token"]).not_to eq(refresh_token)
      end
    end

    context "with invalid refresh token" do
      it "returns HTTP unauthorized" do
        post path, params: { refresh_token: 'invalid_token' }.to_json, headers: headers
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns invalid token error" do
        post path, params: { refresh_token: 'invalid_token' }.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json["error"]).to eq("invalid_token")
        expect(json["message"]).to eq("Invalid refresh token")
      end
    end

    context "with expired refresh token" do
      it "returns HTTP unauthorized" do
        expired_token = JWT.encode(
          { user_id: user.id, exp: 1.hour.ago.to_i },
          Rails.application.credentials.secret_key_base,
          'HS256'
        )
        
        post path, params: { refresh_token: expired_token }.to_json, headers: headers
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns expired token error" do
        expired_token = JWT.encode(
          { user_id: user.id, exp: 1.hour.ago.to_i },
          Rails.application.credentials.secret_key_base,
          'HS256'
        )
        
        post path, params: { refresh_token: expired_token }.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json["error"]).to eq("token_expired")
        expect(json["message"]).to eq("Refresh token has expired")
      end
    end

    context "with missing refresh token" do
      it "returns HTTP unprocessable entity" do
        post path, params: {}.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns missing token error" do
        post path, params: {}.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json["error"]).to eq("missing_token")
        expect(json["message"]).to eq("Refresh token is required")
      end
    end
  end

  describe "GET /api/v1/auth/validate" do
    let(:path) { "/api/v1/auth/validate" }

    context "with valid token" do
      it "returns HTTP success" do
        post "/api/v1/auth/login", params: { email: user.email, password: 'password123' }.to_json, headers: headers
        token = JSON.parse(response.body)["data"]["token"]
        
        get path, headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:success)
      end

      it "returns valid true" do
        post "/api/v1/auth/login", params: { email: user.email, password: 'password123' }.to_json, headers: headers
        token = JSON.parse(response.body)["data"]["token"]
        
        get path, headers: { "Authorization" => "Bearer #{token}" }
        json = JSON.parse(response.body)
        
        expect(json["data"]["valid"]).to be true
      end

      it "returns user information" do
        post "/api/v1/auth/login", params: { email: user.email, password: 'password123' }.to_json, headers: headers
        token = JSON.parse(response.body)["data"]["token"]
        
        get path, headers: { "Authorization" => "Bearer #{token}" }
        json = JSON.parse(response.body)
        
        expect(json["data"]["user_id"]).to eq(user.id.to_s)
        expect(json["data"]["email"]).to eq(user.email)
      end

      it "returns token expiration" do
        post "/api/v1/auth/login", params: { email: user.email, password: 'password123' }.to_json, headers: headers
        token = JSON.parse(response.body)["data"]["token"]
        
        get path, headers: { "Authorization" => "Bearer #{token}" }
        json = JSON.parse(response.body)
        
        expect(json["data"]["expires_at"]).to be_present
      end
    end

    context "with invalid token" do
      it "returns HTTP unauthorized" do
        get path, headers: { "Authorization" => "Bearer invalid_token" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns invalid token error" do
        get path, headers: { "Authorization" => "Bearer invalid_token" }
        json = JSON.parse(response.body)
        
        expect(json["error"]).to eq("invalid_token")
        expect(json["message"]).to eq("Invalid token")
      end
    end

    context "with expired token" do
      it "returns HTTP unauthorized" do
        expired_token = JWT.encode(
          { user_id: user.id, exp: 1.hour.ago.to_i },
          Rails.application.credentials.secret_key_base,
          'HS256'
        )
        
        get path, headers: { "Authorization" => "Bearer #{expired_token}" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns expired token error" do
        expired_token = JWT.encode(
          { user_id: user.id, exp: 1.hour.ago.to_i },
          Rails.application.credentials.secret_key_base,
          'HS256'
        )
        
        get path, headers: { "Authorization" => "Bearer #{expired_token}" }
        json = JSON.parse(response.body)
        
        expect(json["error"]).to eq("token_expired")
        expect(json["message"]).to eq("Token has expired")
      end
    end

    context "with missing token" do
      it "returns HTTP unauthorized" do
        get path
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns missing token error" do
        get path
        json = JSON.parse(response.body)
        
        expect(json["error"]).to eq("missing_token")
        expect(json["message"]).to eq("Token is required")
      end
    end
  end

  describe "POST /api/v1/auth/logout" do
    let(:path) { "/api/v1/auth/logout" }

    context "with valid token" do
      it "returns HTTP success" do
        post "/api/v1/auth/login", params: { email: user.email, password: 'password123' }.to_json, headers: headers
        token = JSON.parse(response.body)["data"]["token"]
        
        post path, headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:success)
      end

      it "invalidates the token" do
        post "/api/v1/auth/login", params: { email: user.email, password: 'password123' }.to_json, headers: headers
        token = JSON.parse(response.body)["data"]["token"]
        
        post path, headers: { "Authorization" => "Bearer #{token}" }
        
        # Token should now be invalid
        get "/api/v1/auth/validate", headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns success message" do
        post "/api/v1/auth/login", params: { email: user.email, password: 'password123' }.to_json, headers: headers
        token = JSON.parse(response.body)["data"]["token"]
        
        post path, headers: { "Authorization" => "Bearer #{token}" }
        json = JSON.parse(response.body)
        
        expect(json["message"]).to eq("Successfully logged out")
      end
    end

    context "with invalid token" do
      it "returns HTTP unauthorized" do
        post path, headers: { "Authorization" => "Bearer invalid_token" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with missing token" do
      it "returns HTTP unauthorized" do
        post path
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/auth/verify_otp" do
    let(:path) { "/api/v1/auth/verify_otp" }

    context "with valid session token and OTP" do
      it "returns HTTP success" do
        # This would normally be set during MFA login
        # For testing, we'll mock the session
        session_token = SecureRandom.uuid
        allow_any_instance_of(AuthController).to receive(:verify_otp_session).and_return(true)
        
        post path, params: { session_token: session_token, otp: '123456' }.to_json, headers: headers
        expect(response).to have_http_status(:success)
      end

      it "returns JWT token" do
        session_token = SecureRandom.uuid
        allow_any_instance_of(AuthController).to receive(:verify_otp_session).and_return(true)
        
        post path, params: { session_token: session_token, otp: '123456' }.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json["data"]["token"]).to be_present
      end
    end

    context "with invalid session token" do
      it "returns HTTP unauthorized" do
        post path, params: { session_token: 'invalid_session', otp: '123456' }.to_json, headers: headers
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns invalid session error" do
        post path, params: { session_token: 'invalid_session', otp: '123456' }.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json["error"]).to eq("invalid_session")
        expect(json["message"]).to eq("Invalid session token")
      end
    end

    context "with invalid OTP" do
      it "returns HTTP unauthorized" do
        session_token = SecureRandom.uuid
        allow_any_instance_of(AuthController).to receive(:verify_otp_session).and_return(true)
        
        post path, params: { session_token: session_token, otp: 'wrong_otp' }.to_json, headers: headers
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns invalid OTP error" do
        session_token = SecureRandom.uuid
        allow_any_instance_of(AuthController).to receive(:verify_otp_session).and_return(true)
        
        post path, params: { session_token: session_token, otp: 'wrong_otp' }.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json["error"]).to eq("invalid_otp")
        expect(json["message"]).to eq("Invalid OTP code")
      end
    end

    context "with missing parameters" do
      it "returns HTTP unprocessable entity for missing session token" do
        post path, params: { otp: '123456' }.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns HTTP unprocessable entity for missing OTP" do
        post path, params: { session_token: 'abc123' }.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "POST /api/v1/auth/password_reset" do
    let(:path) { "/api/v1/auth/password_reset" }

    context "with valid email" do
      it "returns HTTP success" do
        post path, params: { email: user.email }.to_json, headers: headers
        expect(response).to have_http_status(:success)
      end

      it "sends password reset email" do
        expect {
          post path, params: { email: user.email }.to_json, headers: headers
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it "returns success message" do
        post path, params: { email: user.email }.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json["message"]).to eq("Password reset instructions sent")
      end
    end

    context "with non-existent email" do
      it "returns HTTP success (for security reasons)" do
        post path, params: { email: 'nonexistent@example.com' }.to_json, headers: headers
        expect(response).to have_http_status(:success)
      end

      it "does not send email" do
        expect {
          post path, params: { email: 'nonexistent@example.com' }.to_json, headers: headers
        }.not_to change { ActionMailer::Base.deliveries.count }
      end
    end

    context "with missing email" do
      it "returns HTTP unprocessable entity" do
        post path, params: {}.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns missing email error" do
        post path, params: {}.to_json, headers: headers
        json = JSON.parse(response.body)
        
        expect(json["error"]).to eq("missing_email")
        expect(json["message"]).to eq("Email is required")
      end
    end
  end

  describe "POST /api/v1/auth/password_update" do
    let(:path) { "/api/v1/auth/password_update" }

    context "with valid reset token and new password" do
      it "returns HTTP success" do
        # First request password reset
        post "/api/v1/auth/password_reset", params: { email: user.email }.to_json, headers: headers
        reset_token = user.reload.password_reset_token
        
        post path, params: { 
          reset_token: reset_token,
          password: 'new_password123',
          password_confirmation: 'new_password123'
        }.to_json, headers: headers
        
        expect(response).to have_http_status(:success)
      end

      it "updates the password" do
        post "/api/v1/auth/password_reset", params: { email: user.email }.to_json, headers: headers
        reset_token = user.reload.password_reset_token
        
        post path, params: { 
          reset_token: reset_token,
          password: 'new_password123',
          password_confirmation: 'new_password123'
        }.to_json, headers: headers
        
        user.reload
        expect(user.valid_password?('new_password123')).to be true
      end

      it "clears the reset token" do
        post "/api/v1/auth/password_reset", params: { email: user.email }.to_json, headers: headers
        reset_token = user.reload.password_reset_token
        
        post path, params: { 
          reset_token: reset_token,
          password: 'new_password123',
          password_confirmation: 'new_password123'
        }.to_json, headers: headers
        
        user.reload
        expect(user.password_reset_token).to be_nil
      end

      it "returns success message" do
        post "/api/v1/auth/password_reset", params: { email: user.email }.to_json, headers: headers
        reset_token = user.reload.password_reset_token
        
        post path, params: { 
          reset_token: reset_token,
          password: 'new_password123',
          password_confirmation: 'new_password123'
        }.to_json, headers: headers
        
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Password updated successfully")
      end
    end

    context "with invalid reset token" do
      it "returns HTTP unauthorized" do
        post path, params: { 
          reset_token: 'invalid_token',
          password: 'new_password123',
          password_confirmation: 'new_password123'
        }.to_json, headers: headers
        
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns invalid token error" do
        post path, params: { 
          reset_token: 'invalid_token',
          password: 'new_password123',
          password_confirmation: 'new_password123'
        }.to_json, headers: headers
        
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("invalid_token")
        expect(json["message"]).to eq("Invalid reset token")
      end
    end

    context "with expired reset token" do
      it "returns HTTP unauthorized" do
        user.update!(password_reset_sent_at: 3.hours.ago)
        
        post path, params: { 
          reset_token: user.password_reset_token,
          password: 'new_password123',
          password_confirmation: 'new_password123'
        }.to_json, headers: headers
        
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns expired token error" do
        user.update!(password_reset_sent_at: 3.hours.ago)
        
        post path, params: { 
          reset_token: user.password_reset_token,
          password: 'new_password123',
          password_confirmation: 'new_password123'
        }.to_json, headers: headers
        
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("token_expired")
        expect(json["message"]).to eq("Reset token has expired")
      end
    end

    context "with mismatched passwords" do
      it "returns HTTP unprocessable entity" do
        post "/api/v1/auth/password_reset", params: { email: user.email }.to_json, headers: headers
        reset_token = user.reload.password_reset_token
        
        post path, params: { 
          reset_token: reset_token,
          password: 'new_password123',
          password_confirmation: 'different_password'
        }.to_json, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns password mismatch error" do
        post "/api/v1/auth/password_reset", params: { email: user.email }.to_json, headers: headers
        reset_token = user.reload.password_reset_token
        
        post path, params: { 
          reset_token: reset_token,
          password: 'new_password123',
          password_confirmation: 'different_password'
        }.to_json, headers: headers
        
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("password_mismatch")
        expect(json["message"]).to eq("Password confirmation doesn't match")
      end
    end

    context "with weak password" do
      it "returns HTTP unprocessable entity" do
        post "/api/v1/auth/password_reset", params: { email: user.email }.to_json, headers: headers
        reset_token = user.reload.password_reset_token
        
        post path, params: { 
          reset_token: reset_token,
          password: 'weak',
          password_confirmation: 'weak'
        }.to_json, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns password too short error" do
        post "/api/v1/auth/password_reset", params: { email: user.email }.to_json, headers: headers
        reset_token = user.reload.password_reset_token
        
        post path, params: { 
          reset_token: reset_token,
          password: 'weak',
          password_confirmation: 'weak'
        }.to_json, headers: headers
        
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("password_too_short")
        expect(json["message"]).to include("is too short")
      end
    end

    context "with missing parameters" do
      it "returns HTTP unprocessable entity for missing reset token" do
        post path, params: { 
          password: 'new_password123',
          password_confirmation: 'new_password123'
        }.to_json, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns HTTP unprocessable entity for missing password" do
        post path, params: { 
          reset_token: 'abc123'
        }.to_json, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
