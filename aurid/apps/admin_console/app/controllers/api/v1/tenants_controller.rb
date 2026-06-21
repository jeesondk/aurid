# API v1 Tenants Controller
# Manages tenant operations via API

module Api
  module V1
    class TenantsController < BaseController
      # Skip tenant verification for index and create (handled manually)
      skip_before_action :verify_tenant_access, only: [:index, :create]
      
      # GET /api/v1/tenants
      # List all tenants (super admin only)
      def index
        authorize_super_admin
        
        tenants = Tenant.actives.ordered_by_name
        
        # Filter by status if provided
        if params[:status].present?
          tenants = tenants.by_status(params[:status])
        end
        
        # Filter by name if provided
        if params[:name].present?
          tenants = tenants.search_by_name(params[:name])
        end
        
        # Paginate
        tenants = paginate(tenants)
        
        api_response(
          data: tenants.map { |t| tenant_serializer(t) },
          meta: pagination_meta(tenants)
        )
      end
      
      # GET /api/v1/tenants/:id
      # Get a specific tenant
      def show
        tenant = find_tenant
        authorize_resource_access(tenant)
        
        api_response(data: tenant_serializer(tenant))
      end
      
      # POST /api/v1/tenants
      # Create a new tenant (super admin only)
      def create
        authorize_super_admin
        
        tenant = Tenant.new(tenant_params)
        
        if tenant.save
          api_response(
            data: tenant_serializer(tenant),
            message: "Tenant created successfully",
            status: :created
          )
        else
          api_validation_error(tenant)
        end
      end
      
      # PATCH /api/v1/tenants/:id
      # Update a tenant
      def update
        tenant = find_tenant
        authorize_resource_access(tenant)
        
        if tenant.update(tenant_params)
          api_response(
            data: tenant_serializer(tenant),
            message: "Tenant updated successfully"
          )
        else
          api_validation_error(tenant)
        end
      end
      
      # DELETE /api/v1/tenants/:id
      # Delete a tenant (soft delete)
      def destroy
        tenant = find_tenant
        authorize_super_admin
        
        tenant.soft_delete
        
        api_response(message: "Tenant deleted successfully")
      end
      
      # POST /api/v1/tenants/:id/restore
      # Restore a deleted tenant
      def restore
        tenant = Tenant.deleted.find_by(id: params[:id])
        
        if tenant.nil?
          return api_not_found("Tenant", params[:id])
        end
        
        authorize_super_admin
        
        tenant.restore
        
        api_response(
          data: tenant_serializer(tenant),
          message: "Tenant restored successfully"
        )
      end
      
      # GET /api/v1/tenants/:id/users
      # List users in a tenant
      def users
        tenant = find_tenant
        authorize_resource_access(tenant)
        
        users = tenant.users.active.ordered_by_name
        
        # Filter by status if provided
        if params[:status].present?
          users = users.where(status: params[:status])
        end
        
        # Filter by email if provided
        if params[:email].present?
          users = users.search_by_email(params[:email])
        end
        
        # Filter by name if provided
        if params[:name].present?
          users = users.search_by_name(params[:name])
        end
        
        # Paginate
        users = paginate(users)
        
        api_response(
          data: users.map { |u| user_serializer(u) },
          meta: pagination_meta(users)
        )
      end
      
      # GET /api/v1/tenants/:id/settings
      # Get tenant settings
      def settings
        tenant = find_tenant
        authorize_resource_access(tenant)
        
        settings = tenant.settings.order(:key)
        
        api_response(
          data: settings.map { |s| setting_serializer(s) }
        )
      end
      
      # POST /api/v1/tenants/:id/regenerate_api_key
      # Regenerate API key for tenant
      def regenerate_api_key
        tenant = find_tenant
        authorize_super_admin
        
        new_key = tenant.generate_new_api_key
        
        api_response(
          data: { api_key: new_key },
          message: "API key regenerated successfully"
        )
      end
      
      private
      
      # Find tenant by ID
      def find_tenant
        tenant = Tenant.actives.find_by(id: params[:id])
        
        if tenant.nil?
          # Check deleted tenants
          tenant = Tenant.deleted.find_by(id: params[:id])
          return tenant if tenant && current_user_super_admin?
          
          api_not_found("Tenant", params[:id])
          return
        end
        
        tenant
      end
      
      # Tenant parameters
      def tenant_params
        params.require(:tenant).permit(
          :name,
          :domain,
          :description,
          :status,
          :tier,
          :max_users,
          :billing_email,
          :billing_address,
          :billing_city,
          :billing_state,
          :billing_zip,
          :billing_country,
          :vat_number,
          metadata: {},
          custom_branding: {}
        )
      end
      
      # Serialize tenant for API response
      def tenant_serializer(tenant)
        {
          id: tenant.id,
          name: tenant.name,
          domain: tenant.domain,
          description: tenant.description,
          status: tenant.status,
          tier: tenant.tier,
          max_users: tenant.max_users,
          user_count: tenant.user_count,
          active_user_count: tenant.active_user_count,
          can_add_users: tenant.can_add_users?,
          users_remaining: tenant.max_users.nil? ? nil : tenant.users_remaining,
          billing_enabled: tenant.billing_enabled?,
          audit_logging_enabled: tenant.audit_logging_enabled?,
          ad_migration_enabled: tenant.ad_migration_enabled?,
          billing_info: billing_info_serializer(tenant),
          created_at: tenant.created_at.iso8601,
          updated_at: tenant.updated_at.iso8601,
          deleted_at: tenant.deleted_at&.iso8601
        }
      end
      
      # Serialize billing info
      def billing_info_serializer(tenant)
        {
          email: tenant.billing_email,
          address: tenant.billing_address,
          city: tenant.billing_city,
          state: tenant.billing_state,
          zip: tenant.billing_zip,
          country: tenant.billing_country,
          vat_number: tenant.vat_number
        }
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
          roles: user.roles.pluck(:name),
          mfa_enabled: user.mfa_enabled?,
          mfa_required: user.mfa_required?,
          created_at: user.created_at.iso8601,
          updated_at: user.updated_at.iso8601
        }
      end
      
      # Serialize setting for API response
      def setting_serializer(setting)
        {
          id: setting.id,
          key: setting.key,
          value: setting.value,
          created_at: setting.created_at.iso8601,
          updated_at: setting.updated_at.iso8601
        }
      end
    end
  end
end
