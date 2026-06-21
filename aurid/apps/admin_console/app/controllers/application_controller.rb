# Base application controller for Admin Console
# All controllers inherit from this

class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  
  # Set current tenant and user for each request
  around_action :set_current_tenant
  around_action :set_current_user
  
  # Handle authentication
  before_action :authenticate_user!
  before_action :verify_tenant_access
  
  # Set default response format
  respond_to :html, :json
  
  # Rescue from common exceptions
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
  rescue_from Pundit::NotAuthorizedError, with: :not_authorized
  rescue_from ActionController::ParameterMissing, with: :bad_request
  rescue_from StandardError, with: :internal_server_error
  
  # Include concerns
  include ErrorHandler
  include AuthenticationHelper
  include AuthorizationHelper
  include TenantHelper
  
  # Default layout
  layout :determine_layout
  
  private
  
  # Set current tenant based on subdomain or request
  def set_current_tenant
    tenant = determine_tenant
    Tenant.current = tenant if tenant
    yield
  ensure
    Tenant.current = nil
  end
  
  # Set current user
  def set_current_user
    user = current_user
    User.current = user if user
    yield
  ensure
    User.current = nil
  end
  
  # Determine tenant from request
  def determine_tenant
    # Try subdomain first
    if request.subdomains.any?
      domain = request.subdomains.first
      Tenant.find_by(domain: domain)
    end
    
    # Fall back to default tenant
    Tenant.default
  end
  
  # Verify user has access to tenant
  def verify_tenant_access
    return true if current_user.nil?
    return true if current_user.super_admin?
    
    # Check if user belongs to the current tenant
    if current_user.tenant_id != Tenant.current&.id
      render json: { error: "Unauthorized access to tenant" }, status: :forbidden
      return false
    end
    
    true
  end
  
  # Determine layout based on request
  def determine_layout
    if request.format.json?
      false # No layout for API responses
    else
      "application"
    end
  end
  
  # Authentication helper methods
  def authenticate_user!
    if request.format.json?
      # For API requests, use JWT authentication
      authenticate_api_user!
    else
      # For web requests, use Devise
      super
    end
  end
  
  def authenticate_api_user!
    # Extract JWT from Authorization header
    auth_header = request.headers["Authorization"]
    
    if auth_header.blank?
      render json: { error: "Authorization header missing" }, status: :unauthorized
      return
    end
    
    token = auth_header.split(" ").last
    
    if token.blank?
      render json: { error: "Bearer token missing" }, status: :unauthorized
      return
    end
    
    # Decode and verify JWT
    begin
      payload = JWT.decode(token, Devise.jwt.secret, true, {
        algorithm: Devise.jwt.signing_algorithm,
        iss: Devise.jwt.issuer,
        aud: Devise.jwt.audience,
        verify_iss: true,
        verify_aud: true
      }).first
      
      # Find user
      user = User.find_by(id: payload["sub"])
      
      if user.nil?
        render json: { error: "User not found" }, status: :unauthorized
        return
      end
      
      # Check if token is revoked
      if JwtDenylist.jwt_revoked?(payload, user)
        render json: { error: "Token revoked" }, status: :unauthorized
        return
      end
      
      # Set current user
      sign_in(user)
      
    rescue JWT::DecodeError => e
      render json: { error: "Invalid token: #{e.message}" }, status: :unauthorized
    end
  end
  
  # Error handlers
  def not_found(exception)
    if request.format.json?
      render json: { error: "Resource not found", message: exception.message }, status: :not_found
    else
      redirect_to root_path, alert: "Resource not found"
    end
  end
  
  def unprocessable_entity(exception)
    if request.format.json?
      render json: { error: "Validation failed", messages: exception.record.errors.full_messages }, status: :unprocessable_entity
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def not_authorized(exception)
    if request.format.json?
      render json: { error: "Not authorized", message: exception.message }, status: :forbidden
    else
      redirect_to root_path, alert: "You are not authorized to perform this action"
    end
  end
  
  def bad_request(exception)
    if request.format.json?
      render json: { error: "Bad request", message: exception.message }, status: :bad_request
    else
      redirect_to root_path, alert: "Bad request"
    end
  end
  
  def internal_server_error(exception)
    if Rails.env.development?
      raise exception
    end
    
    if request.format.json?
      render json: { error: "Internal server error" }, status: :internal_server_error
    else
      render "errors/internal_server_error", status: :internal_server_error
    end
  end
end

# Error handler concern
module ErrorHandler
  extend ActiveSupport::Concern
  
  included do
    rescue_from StandardError, with: :handle_standard_error
  end
  
  private
  
  def handle_standard_error(exception)
    if Rails.env.development?
      raise exception
    end
    
    logger.error "Error: #{exception.message}"
    logger.error exception.backtrace.join("\n")
    
    if request.format.json?
      render json: { error: "An error occurred" }, status: :internal_server_error
    else
      render "errors/internal_server_error", status: :internal_server_error
    end
  end
end

# Authentication helper concern
module AuthenticationHelper
  extend ActiveSupport::Concern
  
  included do
    helper_method :current_tenant
    helper_method :current_user_admin?
    helper_method :current_user_super_admin?
  end
  
  def current_tenant
    Tenant.current || Tenant.default
  end
  
  def current_user_admin?
    current_user&.admin? || current_user&.super_admin?
  end
  
  def current_user_super_admin?
    current_user&.super_admin?
  end
end

# Authorization helper concern
module AuthorizationHelper
  extend ActiveSupport::Concern
  
  included do
    helper_method :authorize_tenant_admin
    helper_method :authorize_super_admin
    helper_method :authorize_resource_access
  end
  
  def authorize_tenant_admin
    unless current_user_admin?
      raise Pundit::NotAuthorizedError, "You must be an admin to perform this action"
    end
  end
  
  def authorize_super_admin
    unless current_user_super_admin?
      raise Pundit::NotAuthorizedError, "You must be a super admin to perform this action"
    end
  end
  
  def authorize_resource_access(resource)
    unless current_user.can_manage_tenant?(resource.tenant)
      raise Pundit::NotAuthorizedError, "You do not have permission to access this resource"
    end
  end
end

# Tenant helper concern
module TenantHelper
  extend ActiveSupport::Concern
  
  included do
    helper_method :set_tenant_by_param
    helper_method :verify_tenant_membership
  end
  
  def set_tenant_by_param
    if params[:tenant_id].present?
      tenant = Tenant.find_by(id: params[:tenant_id])
      Tenant.current = tenant if tenant
    end
  end
  
  def verify_tenant_membership
    return true if current_user.super_admin?
    
    if current_user.tenant_id != Tenant.current&.id
      render json: { error: "You do not have access to this tenant" }, status: :forbidden
      return false
    end
    
    true
  end
end
