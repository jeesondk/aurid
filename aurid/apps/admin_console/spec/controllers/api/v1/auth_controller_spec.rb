# API v1 Authentication Controller Tests

require "rails_helper"

RSpec.describe Api::V1::AuthController, type: :controller do
  let(:user) { create(:user, :confirmed, password: "TestPassword123!", password_confirmation: "TestPassword123!") }
  let(:tenant) { user.tenant }
  let(:valid_credentials) { { email: user.email, password: "TestPassword123!" } }
  let(:invalid_credentials) { { email: "invalid@example.com", password: "wrongpassword" } }

  describe "POST #login" do
    context "with valid credentials" do
      it "returns JWT token and user info" do
        post :login, params: valid_credentials
        
        expect(response).to have_http_status(:success)
        expect(json_response[:success]).to be true
        expect(json_response[:data][:token]).to be_present
        expect(json_response[:data][:refresh_token]).to be_present
        expect(json_response[:data][:token_type]).to eq("Bearer")
        expect(json_response[:data][:expires_in]).to be_present
      end
      
      it "returns user information" do
        post :login, params: valid_credentials
        
        user_data = json_response[:data][:user]
        expect(user_data[:id]).to eq(user.id.to_s)
        expect(user_data[:email]).to eq(user.email)
        expect(user_data[:first_name]).to eq(user.first_name)
        expect(user_data[:last_name]).to eq(user.last_name)
        expect(user_data[:tenant_id]).to eq(user.tenant_id.to_s)
        expect(user_data[:roles]).to include("viewer")
      end
      
      it "sets tenant context" do
        post :login, params: valid_credentials
        expect(Tenant.current).to eq(tenant)
      end
      
      it "returns proper headers" do
        post :login, params: valid_credentials
        
        expect(response.headers["X-API-Version"]).to eq("1.0")
        expect(response.headers["X-Request-ID"]).to be_present
      end
    end
    
    context "with missing credentials" do
      it "returns error when email is missing" do
        post :login, params: { password: "TestPassword123!" }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:success]).to be false
        expect(json_response[:error]).to eq("invalid_credentials")
        expect(json_response[:message]).to eq("Email and password are required")
      end
      
      it "returns error when password is missing" do
        post :login, params: { email: user.email }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:success]).to be false
        expect(json_response[:error]).to eq("invalid_credentials")
      end
      
      it "returns error when both are missing" do
        post :login, params: {}
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error]).to eq("invalid_credentials")
      end
    end
    
    context "with invalid credentials" do
      it "returns error for wrong password" do
        post :login, params: { email: user.email, password: "wrongpassword" }
        
        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:success]).to be false
        expect(json_response[:error]).to eq("invalid_credentials")
        expect(json_response[:message]).to eq("Invalid email or password")
      end
      
      it "returns error for non-existent user" do
        post :login, params: { email: "nonexistent@example.com", password: "TestPassword123!" }
        
        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:success]).to be false
        expect(json_response[:error]).to eq("invalid_credentials")
      end
      
      it "prevents email enumeration" do
        # Both non-existent user and wrong password return same error
        post :login, params: { email: "nonexistent@example.com", password: "wrongpassword" }
        expect(json_response[:message]).to eq("Invalid email or password")
        
        post :login, params: { email: user.email, password: "wrongpassword" }
        expect(json_response[:message]).to eq("Invalid email or password")
      end
    end
    
    context "with inactive user" do
      let(:inactive_user) { create(:user, :suspended, :confirmed, password: "TestPassword123!") }
      
      it "returns error for suspended user" do
        post :login, params: { email: inactive_user.email, password: "TestPassword123!" }
        
        expect(response).to have_http_status(:forbidden)
        expect(json_response[:error]).to eq("account_disabled")
        expect(json_response[:message]).to eq("Your account has been disabled")
      end
    end
    
    context "with unconfirmed user" do
      let(:unconfirmed_user) { create(:user, :unconfirmed, password: "TestPassword123!") }
      
      it "returns error for unconfirmed user" do
        post :login, params: { email: unconfirmed_user.email, password: "TestPassword123!" }
        
        expect(response).to have_http_status(:forbidden)
        expect(json_response[:error]).to eq("unconfirmed")
        expect(json_response[:message]).to eq("Your account has not been confirmed")
      end
    end
    
    context "with case-insensitive email" do
      it "finds user with different case email" do
        post :login, params: { email: user.email.upcase, password: "TestPassword123!" }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:data][:user][:email]).to eq(user.email)
      end
    end
  end

  describe "POST #logout" do
    context "with authenticated user" do
      before do
        sign_in_user(user)
        request.headers["Authorization"] = "Bearer #{generate_jwt_token(user)}"
      end
      
      it "returns success message" do
        post :logout
        
        expect(response).to have_http_status(:success)
        expect(json_response[:success]).to be true
        expect(json_response[:message]).to eq("Successfully logged out")
      end
      
      it "revokes the JWT token" do
        token = generate_jwt_token(user)
        request.headers["Authorization"] = "Bearer #{token}"
        
        # Decode token to get JTI
        payload = JWT.decode(token, Devise.jwt.secret, false).first
        jti = payload["jti"]
        
        expect { post :logout }.to change { JwtDenylist.where(jti: jti).count }.by(1)
      end
      
      it "deactivates all user sessions" do
        create(:session, :active, user: user)
        create(:session, :active, user: user)
        
        expect { post :logout }.to change { user.sessions.active.count }.by(-2)
      end
    end
    
    context "without authorization header" do
      it "still returns success" do
        post :logout
        
        expect(response).to have_http_status(:success)
        expect(json_response[:success]).to be true
      end
    end
    
    context "with invalid token" do
      it "returns success without error" do
        request.headers["Authorization"] = "Bearer invalid.token.here"
        
        post :logout
        
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "POST #refresh" do
    let(:refresh_token) do
      payload = {
        sub: user.id,
        jti: SecureRandom.uuid,
        iat: Time.current.to_i,
        exp: 7.days.from_now.to_i,
        token_type: "refresh"
      }
      JWT.encode(payload, Devise.jwt.secret, Devise.jwt.signing_algorithm)
    end
    
    context "with valid refresh token" do
      it "returns new tokens" do
        post :refresh, params: { refresh_token: refresh_token }
        
        expect(response).to have_http_status(:success)
        expect(json_response[:success]).to be true
        expect(json_response[:data][:token]).to be_present
        expect(json_response[:data][:refresh_token]).to be_present
        expect(json_response[:data][:token_type]).to eq("Bearer")
      end
      
      it "returns different access token" do
        old_token = generate_jwt_token(user)
        post :refresh, params: { refresh_token: refresh_token }
        
        expect(json_response[:data][:token]).not_to eq(old_token)
      end
    end
    
    context "with missing refresh token" do
      it "returns error" do
        post :refresh, params: {}
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:success]).to be false
        expect(json_response[:error]).to eq("invalid_request")
        expect(json_response[:message]).to eq("Refresh token is required")
      end
    end
    
    context "with invalid refresh token" do
      it "returns error for malformed token" do
        post :refresh, params: { refresh_token: "invalid.token" }
        
        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:success]).to be false
        expect(json_response[:error]).to eq("invalid_token")
      end
      
      it "returns error for expired token" do
        expired_payload = {
          sub: user.id,
          jti: SecureRandom.uuid,
          iat: Time.current.to_i,
          exp: 1.hour.ago.to_i,
          token_type: "refresh"
        }
        expired_token = JWT.encode(expired_payload, Devise.jwt.secret, Devise.jwt.signing_algorithm)
        
        post :refresh, params: { refresh_token: expired_token }
        
        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:error]).to eq("token_expired")
      end
    end
    
    context "with disabled user" do
      let(:disabled_user) { create(:user, :disabled, :confirmed, password: "TestPassword123!") }
      
      it "returns error for disabled user" do
        payload = {
          sub: disabled_user.id,
          jti: SecureRandom.uuid,
          iat: Time.current.to_i,
          exp: 7.days.from_now.to_i,
          token_type: "refresh"
        }
        token = JWT.encode(payload, Devise.jwt.secret, Devise.jwt.signing_algorithm)
        
        post :refresh, params: { refresh_token: token }
        
        expect(response).to have_http_status(:forbidden)
        expect(json_response[:error]).to eq("account_disabled")
      end
    end
  end

  describe "GET #me" do
    context "with authenticated user" do
      before do
        sign_in_user(user)
        request.headers["Authorization"] = "Bearer #{generate_jwt_token(user)}"
      end
      
      it "returns current user information" do
        get :me
        
        expect(response).to have_http_status(:success)
        expect(json_response[:success]).to be true
        expect(json_response[:data][:user][:id]).to eq(user.id.to_s)
        expect(json_response[:data][:user][:email]).to eq(user.email)
      end
      
      it "returns user roles and permissions" do
        get :me
        
        user_data = json_response[:data][:user]
        expect(user_data[:roles]).to be_present
        expect(user_data[:permissions]).to be_present
      end
      
      it "returns timestamps" do
        get :me
        
        user_data = json_response[:data][:user]
        expect(user_data[:created_at]).to be_present
        expect(user_data[:updated_at]).to be_present
      end
    end
    
    context "without authentication" do
      it "returns unauthorized error" do
        get :me
        
        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:success]).to be false
        expect(json_response[:error]).to eq("unauthorized")
      end
    end
  end

  # Helper method to generate JWT token
  def generate_jwt_token(user)
    payload = user.jwt_payload
    payload[:exp] = 1.hour.from_now.to_i
    JWT.encode(payload, Devise.jwt.secret, Devise.jwt.signing_algorithm)
  end
end
