# Base controller for API v1 endpoints
# All API v1 controllers inherit from this

module Api
  module V1
    class BaseController < ApplicationController
      # Skip CSRF for API endpoints
      skip_before_action :verify_authenticity_token
      
      # Force JSON response
      before_action :force_json_response
      
      # Set default headers
      after_action :set_api_headers
      
      # Pagination defaults
      DEFAULT_PER_PAGE = 25
      MAX_PER_PAGE = 100
      
      private
      
      # Force JSON response
      def force_json_response
        request.format = :json
      end
      
      # Set API headers
      def set_api_headers
        response.headers["X-API-Version"] = "1.0"
        response.headers["X-Request-ID"] = request.request_id
      end
      
      # Pagination helper
      def paginate(collection)
        page = params[:page] || 1
        per_page = params[:per_page] || DEFAULT_PER_PAGE
        per_page = [per_page.to_i, MAX_PER_PAGE].min
        
        collection.page(page).per(per_page)
      end
      
      # Pagination metadata
      def pagination_meta(collection)
        {
          current_page: collection.current_page,
          total_pages: collection.total_pages,
          total_count: collection.total_count,
          per_page: collection.limit_value,
          next_page: collection.next_page,
          prev_page: collection.prev_page
        }
      end
      
      # Standard API response
      def api_response(data: nil, meta: nil, status: :ok)
        response = { success: true }
        response[:data] = data if data.present?
        response[:meta] = meta if meta.present?
        
        render json: response, status: status
      end
      
      # Error API response
      def api_error(error: nil, message: nil, status: :bad_request, details: nil)
        response = { success: false, error: error || "An error occurred" }
        response[:message] = message if message.present?
        response[:details] = details if details.present?
        
        render json: response, status: status
      end
      
      # Not found response
      def api_not_found(resource: nil, id: nil)
        message = "#{resource || 'Resource'} not found"
        message += " with ID: #{id}" if id
        
        api_error(error: "not_found", message: message, status: :not_found)
      end
      
      # Unauthorized response
      def api_unauthorized(message: nil)
        api_error(
          error: "unauthorized",
          message: message || "You are not authorized to perform this action",
          status: :unauthorized
        )
      end
      
      # Forbidden response
      def api_forbidden(message: nil)
        api_error(
          error: "forbidden",
          message: message || "You do not have permission to access this resource",
          status: :forbidden
        )
      end
      
      # Validation error response
      def api_validation_error(record)
        api_error(
          error: "validation_failed",
          message: "Validation failed",
          status: :unprocessable_entity,
          details: record.errors.full_messages
        )
      end
      
      # Rate limit exceeded response
      def api_rate_limit_exceeded
        api_error(
          error: "rate_limit_exceeded",
          message: "Too many requests",
          status: :too_many_requests
        )
      end
      
      # Current tenant for API
      def current_tenant
        @current_tenant ||= begin
          # Try to get tenant from subdomain
          if request.subdomains.any?
            Tenant.find_by(domain: request.subdomains.first)
          end
          
          # Fall back to default
          Tenant.default
        end
      end
      
      # Verify API key authentication
      def verify_api_key
        api_key = request.headers["X-API-Key"] || params[:api_key]
        
        if api_key.blank?
          api_unauthorized("API key required")
          return false
        end
        
        # Find tenant by API key
        tenant = Tenant.find_by(api_key_digest: Digest::SHA256.hexdigest(api_key))
        
        if tenant.nil?
          api_unauthorized("Invalid API key")
          return false
        end
        
        Tenant.current = tenant
        true
      end
    end
  end
end
