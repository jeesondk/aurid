# API v1 Authentication Controller
# Handles JWT authentication for API clients

module Api
  module V1
    class AuthController < BaseController
      # Skip authentication for login endpoint
      skip_before_action :authenticate_user!, only: [:login, :refresh]
      skip_before_action :verify_tenant_access, only: [:login, :refresh, :logout]
      
      # POST /api/v1/auth/login
      # Authenticate user and return JWT token
      def login
        email = params[:email]
        password = params[:password]
        
        if email.blank? || password.blank?
          return api_error(
            error: "invalid_credentials",
            message: "Email and password are required",
            status: :unprocessable_entity
          )
        end
        
        # Find user by email
        user = User.find_by(email: email.downcase)
        
        if user.nil?
          # Return generic error to prevent email enumeration
          return api_error(
            error: "invalid_credentials",
            message: "Invalid email or password",
            status: :unauthorized
          )
        end
        
        # Check if user is active
        unless user.active?
          return api_error(
            error: "account_disabled",
            message: "Your account has been disabled",
            status: :forbidden
          )
        end
        
        # Verify password
        if !user.valid_password?(password)
          # Return generic error to prevent email enumeration
          return api_error(
            error: "invalid_credentials",
            message: "Invalid email or password",
            status: :unauthorized
          )
        end
        
        # Check if user is confirmed
        unless user.confirmed?
          return api_error(
            error: "unconfirmed",
            message: "Your account has not been confirmed",
            status: :forbidden
          )
        end
        
        # Check if MFA is required
        if user.mfa_required? && user.mfa_enabled?
          # For now, we'll skip MFA verification
          # In production, you would return a challenge
          # and require MFA code verification
        end
        
        # Generate JWT token
        token = generate_jwt_token(user)
        refresh_token = generate_refresh_token(user)
        
        # Set tenant context
        Tenant.current = user.tenant
        
        # Return tokens and user info
        api_response(
          data: {
            token: token,
            refresh_token: refresh_token,
            token_type: "Bearer",
            expires_in: Rails.application.config.jwt.expiration_time,
            user: user_serializer(user)
          }
        )
      end
      
      # POST /api/v1/auth/logout
      # Invalidate current JWT token
      def logout
        # Extract token from Authorization header
        auth_header = request.headers["Authorization"]
        
        if auth_header.present?
          token = auth_header.split(" ").last
          
          if token.present?
            # Decode token to get JTI
            begin
              payload = JWT.decode(token, Devise.jwt.secret, false).first
              jti = payload["jti"]
              
              if jti.present?
                # Add to denylist
                JwtDenylist.create!(jti: jti, expires_at: Time.at(payload["exp"]))
              end
            rescue JWT::DecodeError
              # Token is already invalid or expired
            end
          end
        end
        
        # Also revoke all sessions for the user
        if current_user
          current_user.deactivate_all_sessions!
        end
        
        api_response(message: "Successfully logged out")
      end
      
      # POST /api/v1/auth/refresh
      # Refresh access token using refresh token
      def refresh
        refresh_token = params[:refresh_token]
        
        if refresh_token.blank?
          return api_error(
            error: "invalid_request",
            message: "Refresh token is required",
            status: :unprocessable_entity
          )
        end
        
        # Decode refresh token
        begin
          payload = JWT.decode(refresh_token, Devise.jwt.secret, true, {
            algorithm: Devise.jwt.signing_algorithm,
            verify_iss: false,
            verify_aud: false
          }).first
          
          # Find user
          user = User.find_by(id: payload["sub"])
          
          if user.nil?
            return api_error(
              error: "invalid_token",
              message: "Invalid refresh token",
              status: :unauthorized
            )
          end
          
          # Check if refresh token is expired
          if Time.at(payload["exp"]) < Time.current
            return api_error(
              error: "token_expired",
              message: "Refresh token has expired",
              status: :unauthorized
            )
          end
          
          # Check if user is still active
          unless user.active?
            return api_error(
              error: "account_disabled",
              message: "Your account has been disabled",
              status: :forbidden
            )
          end
          
          # Generate new tokens
          token = generate_jwt_token(user)
          new_refresh_token = generate_refresh_token(user)
          
          api_response(
            data: {
              token: token,
              refresh_token: new_refresh_token,
              token_type: "Bearer",
              expires_in: Rails.application.config.jwt.expiration_time
            }
          )
          
        rescue JWT::DecodeError => e
          api_error(
            error: "invalid_token",
            message: "Invalid refresh token: #{e.message}",
            status: :unauthorized
          )
        end
      end
      
      # GET /api/v1/auth/me
      # Get current user information
      def me
        user = current_user
        
        if user.nil?
          return api_unauthorized("Authentication required")
        end
        
        api_response(data: { user: user_serializer(user) })
      end
      
      private
      
      # Generate JWT access token
      def generate_jwt_token(user)
        payload = user.jwt_payload
        payload[:exp] = Rails.application.config.jwt.expiration_time.seconds.from_now.to_i
        
        JWT.encode(payload, Devise.jwt.secret, Devise.jwt.signing_algorithm)
      end
      
      # Generate refresh token
      def generate_refresh_token(user)
        payload = {
          sub: user.id,
          jti: SecureRandom.uuid,
          iat: Time.current.to_i,
          exp: Rails.application.config.jwt.refresh_expiration_time.seconds.from_now.to_i,
          token_type: "refresh"
        }
        
        JWT.encode(payload, Devise.jwt.secret, Devise.jwt.signing_algorithm)
      end
      
      # Serialize user for API response
      def user_serializer(user)
        {
          id: user.id,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          full_name: user.full_name,
          display_name: user.display_name,
          status: user.status,
          tenant_id: user.tenant_id,
          roles: user.roles.pluck(:name),
          permissions: user.roles.flat_map(&:permissions).uniq,
          mfa_enabled: user.mfa_enabled?,
          mfa_required: user.mfa_required?,
          timezone: user.timezone,
          locale: user.locale,
          created_at: user.created_at.iso8601,
          updated_at: user.updated_at.iso8601,
          last_active_at: user.last_active_at&.iso8601
        }
      end
    end
  end
end
