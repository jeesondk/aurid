# API v1 Users Controller
# Manages user operations via API

module Api
  module V1
    class UsersController < BaseController
      # GET /api/v1/users
      # List all users (super admin only)
      def index
        authorize_super_admin
        
        users = User.actives.ordered_by_name
        
        # Filter by tenant if provided
        if params[:tenant_id].present?
          tenant = Tenant.find_by(id: params[:tenant_id])
          if tenant.nil?
            return api_not_found("Tenant", params[:tenant_id])
          end
          users = users.by_tenant(tenant)
        end
        
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
        
        # Filter by role if provided
        if params[:role].present?
          role = Role.find_by(name: params[:role])
          if role
            users = users.joins(:roles).where(roles: { id: role.id })
          end
        end
        
        # Paginate
        users = paginate(users)
        
        api_response(
          data: users.map { |u| user_serializer(u) },
          meta: pagination_meta(users)
        )
      end
      
      # GET /api/v1/users/:id
      # Get a specific user
      def show
        user = find_user
        authorize_resource_access(user.tenant)
        
        api_response(data: user_serializer(user))
      end
      
      # POST /api/v1/users
      # Create a new user
      def create
        # Check if user can create users in the target tenant
        tenant = find_tenant_by_param
        authorize_resource_access(tenant)
        
        # Check if tenant can add more users
        unless tenant.can_add_users?
          return api_error(
            error: "limit_reached",
            message: "Tenant has reached maximum user limit",
            status: :forbidden
          )
        end
        
        user = User.new(user_params.merge(tenant: tenant))
        
        if user.save
          # Assign roles if provided
          if params[:role_names].present?
            assign_roles(user, params[:role_names])
          end
          
          api_response(
            data: user_serializer(user),
            message: "User created successfully",
            status: :created
          )
        else
          api_validation_error(user)
        end
      end
      
      # PATCH /api/v1/users/:id
      # Update a user
      def update
        user = find_user
        authorize_resource_access(user.tenant)
        
        if user.update(user_params)
          # Update roles if provided
          if params[:role_names].present?
            assign_roles(user, params[:role_names])
          end
          
          api_response(
            data: user_serializer(user),
            message: "User updated successfully"
          )
        else
          api_validation_error(user)
        end
      end
      
      # DELETE /api/v1/users/:id
      # Delete a user (soft delete)
      def destroy
        user = find_user
        authorize_resource_access(user.tenant)
        
        # Prevent deleting self
        if user == current_user
          return api_error(
            error: "cannot_delete_self",
            message: "You cannot delete your own account",
            status: :forbidden
          )
        end
        
        user.soft_delete
        
        api_response(message: "User deleted successfully")
      end
      
      # POST /api/v1/users/:id/restore
      # Restore a deleted user
      def restore
        user = User.deleted.find_by(id: params[:id])
        
        if user.nil?
          return api_not_found("User", params[:id])
        end
        
        authorize_resource_access(user.tenant)
        
        user.restore
        
        api_response(
          data: user_serializer(user),
          message: "User restored successfully"
        )
      end
      
      # POST /api/v1/users/:id/suspend
      # Suspend a user
      def suspend
        user = find_user
        authorize_resource_access(user.tenant)
        
        # Prevent suspending self
        if user == current_user
          return api_error(
            error: "cannot_suspend_self",
            message: "You cannot suspend your own account",
            status: :forbidden
          )
        end
        
        user.update(status: :suspended)
        
        api_response(
          data: user_serializer(user),
          message: "User suspended successfully"
        )
      end
      
      # POST /api/v1/users/:id/reactivate
      # Reactivate a suspended user
      def reactivate
        user = find_user
        authorize_resource_access(user.tenant)
        
        user.update(status: :active)
        
        api_response(
          data: user_serializer(user),
          message: "User reactivated successfully"
        )
      end
      
      # POST /api/v1/users/:id/reset_password
      # Reset user password
      def reset_password
        user = find_user
        authorize_resource_access(user.tenant)
        
        new_password = params[:new_password]
        
        if new_password.blank?
          return api_error(
            error: "password_required",
            message: "New password is required",
            status: :unprocessable_entity
          )
        end
        
        if new_password.length < 12
          return api_error(
            error: "password_too_short",
            message: "Password must be at least 12 characters",
            status: :unprocessable_entity
          )
        end
        
        user.update(password: new_password, password_confirmation: new_password)
        
        api_response(message: "Password reset successfully")
      end
      
      # GET /api/v1/users/:id/audit_logs
      # Get audit logs for a user
      def audit_logs
        user = find_user
        authorize_resource_access(user.tenant)
        
        logs = user.audit_logs.order(created_at: :desc)
        
        # Filter by action if provided
        if params[:action].present?
          logs = logs.where(action: params[:action])
        end
        
        # Filter by resource type if provided
        if params[:resource_type].present?
          logs = logs.where(resource_type: params[:resource_type])
        end
        
        # Filter by date range if provided
        if params[:start_date].present?
          logs = logs.where("created_at >= ?", params[:start_date])
        end
        
        if params[:end_date].present?
          logs = logs.where("created_at <= ?", params[:end_date])
        end
        
        # Paginate
        logs = paginate(logs)
        
        api_response(
          data: logs.map { |l| audit_log_serializer(l) },
          meta: pagination_meta(logs)
        )
      end
      
      private
      
      # Find user by ID
      def find_user
        user = User.actives.find_by(id: params[:id])
        
        if user.nil?
          # Check deleted users
          user = User.deleted.find_by(id: params[:id])
          return user if user && current_user_super_admin?
          
          api_not_found("User", params[:id])
          return
        end
        
        user
      end
      
      # Find tenant by param
      def find_tenant_by_param
        if params[:tenant_id].present?
          tenant = Tenant.find_by(id: params[:tenant_id])
          if tenant.nil?
            api_not_found("Tenant", params[:tenant_id])
            return
          end
          tenant
        else
          current_tenant
        end
      end
      
      # User parameters
      def user_params
        params.require(:user).permit(
          :email,
          :first_name,
          :last_name,
          :password,
          :password_confirmation,
          :phone,
          :job_title,
          :department,
          :avatar_url,
          :timezone,
          :locale,
          :status,
          :metadata,
          :preferences
        )
      end
      
      # Assign roles to user
      def assign_roles(user, role_names)
        # Clear existing roles
        user.user_roles.destroy_all
        
        # Assign new roles
        role_names.each do |role_name|
          role = Role.find_by(name: role_name)
          if role
            user.user_roles.create(role: role)
          end
        end
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
          tenant_name: user.tenant&.name,
          roles: user.roles.pluck(:name),
          permissions: user.roles.flat_map(&:permissions).uniq,
          phone: user.phone,
          job_title: user.job_title,
          department: user.department,
          avatar_url: user.avatar_url,
          timezone: user.timezone,
          locale: user.locale,
          mfa_enabled: user.mfa_enabled?,
          mfa_required: user.mfa_required?,
          can_manage_tenant: user.can_manage_tenant?(user.tenant),
          can_manage_users: user.can_manage_users?,
          can_manage_settings: user.can_manage_settings?,
          created_at: user.created_at.iso8601,
          updated_at: user.updated_at.iso8601,
          last_active_at: user.last_active_at&.iso8601
        }
      end
      
      # Serialize audit log for API response
      def audit_log_serializer(log)
        {
          id: log.id,
          action: log.action,
          resource_type: log.resource_type,
          resource_id: log.resource_id,
          changes: log.changes,
          metadata: log.metadata,
          ip_address: log.ip_address,
          user_agent: log.user_agent,
          created_at: log.created_at.iso8601
        }
      end
    end
  end
end
