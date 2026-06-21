# Keycloak Service
# Handles integration with Keycloak for identity management

class KeycloakService < BaseService
  # Keycloak client for admin operations
  class AdminClient
    attr_reader :config
    
    def initialize(config = Rails.application.config.keycloak)
      @config = config
      @client = build_client
    end
    
    def build_client
      KeycloakAdmin::Client.new(
        server_url: @config.url,
        realm: @config.realm,
        username: @config.admin_username,
        password: @config.admin_password,
        client_id: "admin-cli",
        client_secret: nil,
        timeout: 30
      )
    end
    
    # Test connection to Keycloak
    def test_connection
      @client.get_realms
      true
    rescue => e
      Rails.logger.error "Keycloak connection test failed: #{e.message}"
      false
    end
    
    # Get realm info
    def get_realm
      @client.get_realm(@config.realm)
    end
    
    # Create realm
    def create_realm(realm_data)
      @client.create_realm(realm_data)
    end
    
    # Update realm
    def update_realm(realm_data)
      @client.update_realm(@config.realm, realm_data)
    end
    
    # Get all realms
    def get_realms
      @client.get_realms
    end
    
    # Get users in realm
    def get_users(options = {})
      @client.get_users(@config.realm, options)
    end
    
    # Get user by ID
    def get_user(user_id)
      @client.get_user(@config.realm, user_id)
    end
    
    # Get user by username
    def get_user_by_username(username)
      @client.get_user_by_username(@config.realm, username)
    end
    
    # Create user
    def create_user(user_data)
      @client.create_user(@config.realm, user_data)
    end
    
    # Update user
    def update_user(user_id, user_data)
      @client.update_user(@config.realm, user_id, user_data)
    end
    
    # Delete user
    def delete_user(user_id)
      @client.delete_user(@config.realm, user_id)
    end
    
    # Reset user password
    def reset_password(user_id, new_password, temporary: false)
      @client.reset_password(@config.realm, user_id, new_password, temporary)
    end
    
    # Enable/disable user
    def set_user_enabled(user_id, enabled)
      @client.set_user_enabled(@config.realm, user_id, enabled)
    end
    
    # Get user groups
    def get_user_groups(user_id)
      @client.get_user_groups(@config.realm, user_id)
    end
    
    # Add user to group
    def add_user_to_group(user_id, group_id)
      @client.add_user_to_group(@config.realm, user_id, group_id)
    end
    
    # Remove user from group
    def remove_user_from_group(user_id, group_id)
      @client.remove_user_from_group(@config.realm, user_id, group_id)
    end
    
    # Get all groups
    def get_groups
      @client.get_groups(@config.realm)
    end
    
    # Get group by ID
    def get_group(group_id)
      @client.get_group(@config.realm, group_id)
    end
    
    # Get group by name
    def get_group_by_name(name)
      @client.get_group_by_name(@config.realm, name)
    end
    
    # Create group
    def create_group(group_data)
      @client.create_group(@config.realm, group_data)
    end
    
    # Update group
    def update_group(group_id, group_data)
      @client.update_group(@config.realm, group_id, group_data)
    end
    
    # Delete group
    def delete_group(group_id)
      @client.delete_group(@config.realm, group_id)
    end
    
    # Get clients
    def get_clients
      @client.get_clients(@config.realm)
    end
    
    # Get client by ID
    def get_client(client_id)
      @client.get_client(@config.realm, client_id)
    end
    
    # Create client
    def create_client(client_data)
      @client.create_client(@config.realm, client_data)
    end
    
    # Update client
    def update_client(client_id, client_data)
      @client.update_client(@config.realm, client_id, client_data)
    end
    
    # Delete client
    def delete_client(client_id)
      @client.delete_client(@config.realm, client_id)
    end
    
    # Get client secret
    def get_client_secret(client_id)
      @client.get_client_secret(@config.realm, client_id)
    end
    
    # Regenerate client secret
    def regenerate_client_secret(client_id)
      @client.regenerate_client_secret(@config.realm, client_id)
    end
    
    # Get roles
    def get_roles
      @client.get_roles(@config.realm)
    end
    
    # Get client roles
    def get_client_roles(client_id)
      @client.get_client_roles(@config.realm, client_id)
    end
    
    # Create role
    def create_role(role_data)
      @client.create_role(@config.realm, role_data)
    end
    
    # Assign role to user
    def assign_role_to_user(user_id, role_data)
      @client.assign_role_to_user(@config.realm, user_id, role_data)
    end
    
    # Remove role from user
    def remove_role_from_user(user_id, role_data)
      @client.remove_role_from_user(@config.realm, user_id, role_data)
    end
  end
  
  # Initialize with user context
  def initialize(user: nil, tenant: nil)
    @user = user
    @tenant = tenant || Tenant.current || Tenant.default
    @admin_client = AdminClient.new
    super()
  end
  
  def setup
    # Set up client for the current tenant
    @client = build_tenant_client
  end
  
  def execute
    # This is a base service, subclasses should implement execute
    success(message: "Service executed successfully")
  end
  
  private
  
  # Build client for the current tenant
  def build_tenant_client
    # In a real implementation, this would use the tenant's Keycloak client
    # For now, we'll use the admin client
    @admin_client
  end
  
  # Helper methods for user sync
  def sync_user_to_keycloak(user)
    # Check if user exists in Keycloak
    keycloak_user = find_keycloak_user(user)
    
    if keycloak_user
      # Update existing user
      update_keycloak_user(user, keycloak_user)
    else
      # Create new user
      create_keycloak_user(user)
    end
    
    success(data: { synced: true, user_id: user.id })
  end
  
  def find_keycloak_user(user)
    # Try to find by username (email)
    begin
      @admin_client.get_user_by_username(user.email)
    rescue KeycloakAdmin::NotFoundError
      nil
    end
  end
  
  def create_keycloak_user(user)
    user_data = {
      username: user.email,
      email: user.email,
      firstName: user.first_name,
      lastName: user.last_name,
      enabled: user.active?,
      emailVerified: user.confirmed?,
      attributes: {
        tenant_id: [user.tenant_id.to_s],
        aurid_user_id: [user.id.to_s]
      },
      credentials: [{
        type: "password",
        value: user.password || SecureRandom.urlsafe_base64(32),
        temporary: false
      }]
    }
    
    @admin_client.create_user(user_data)
  end
  
  def update_keycloak_user(user, keycloak_user)
    user_data = {
      firstName: user.first_name,
      lastName: user.last_name,
      email: user.email,
      enabled: user.active?,
      emailVerified: user.confirmed?,
      attributes: {
        tenant_id: [user.tenant_id.to_s],
        aurid_user_id: [user.id.to_s]
      }
    }
    
    @admin_client.update_user(keycloak_user[:id], user_data)
  end
  
  # Helper methods for group sync
  def sync_group_to_keycloak(group)
    # Check if group exists in Keycloak
    keycloak_group = find_keycloak_group(group)
    
    if keycloak_group
      # Update existing group
      update_keycloak_group(group, keycloak_group)
    else
      # Create new group
      create_keycloak_group(group)
    end
    
    success(data: { synced: true, group_id: group.id })
  end
  
  def find_keycloak_group(group)
    begin
      @admin_client.get_group_by_name(group.name)
    rescue KeycloakAdmin::NotFoundError
      nil
    end
  end
  
  def create_keycloak_group(group)
    group_data = {
      name: group.name,
      attributes: {
        tenant_id: [group.tenant_id.to_s],
        aurid_group_id: [group.id.to_s]
      }
    }
    
    @admin_client.create_group(group_data)
  end
  
  def update_keycloak_group(group, keycloak_group)
    group_data = {
      name: group.name,
      attributes: {
        tenant_id: [group.tenant_id.to_s],
        aurid_group_id: [group.id.to_s]
      }
    }
    
    @admin_client.update_group(keycloak_group[:id], group_data)
  end
end

# User sync service
class KeycloakUserSyncService < KeycloakService
  def initialize(user: nil, tenant: nil)
    @user = user
    super(user: user, tenant: tenant)
  end
  
  def execute
    return failure(error: :user_required, message: "User is required") if @user.nil?
    
    begin
      sync_user_to_keycloak(@user)
    rescue => e
      failure(error: :sync_failed, message: "Failed to sync user: #{e.message}")
    end
  end
end

# Group sync service
class KeycloakGroupSyncService < KeycloakService
  def initialize(group: nil, tenant: nil)
    @group = group
    super(tenant: tenant)
  end
  
  def execute
    return failure(error: :group_required, message: "Group is required") if @group.nil?
    
    begin
      sync_group_to_keycloak(@group)
    rescue => e
      failure(error: :sync_failed, message: "Failed to sync group: #{e.message}")
    end
  end
end

# Full sync service
class KeycloakFullSyncService < KeycloakService
  def initialize(tenant: nil)
    @tenant = tenant || Tenant.current || Tenant.default
    super(tenant: @tenant)
  end
  
  def execute
    # Sync all users in tenant
    @tenant.users.find_each do |user|
      KeycloakUserSyncService.call(user: user, tenant: @tenant)
    end
    
    # Sync all roles as groups
    Role.where(global: true).find_each do |role|
      # Create a group for each role
      group = @tenant.applications.first || create_default_group(role)
      KeycloakGroupSyncService.call(group: group, tenant: @tenant)
    end
    
    success(
      data: {
        synced_users: @tenant.users.count,
        synced_groups: Role.global.count
      },
      message: "Full sync completed successfully"
    )
  end
  
  private
  
  def create_default_group(role)
    # Create a default application for role groups
    Application.find_or_create_by!(
      tenant: @tenant,
      name: "Role Groups",
      app_type: :oidc,
      client_id: "role-groups",
      enabled: true
    )
  end
end

# Setup service
class KeycloakSetupService < KeycloakService
  def initialize(tenant: nil)
    @tenant = tenant || Tenant.current || Tenant.default
    super(tenant: @tenant)
  end
  
  def execute
    # Check if realm exists
    begin
      realm = @admin_client.get_realm(@config.realm)
      success(data: { realm: realm }, message: "Realm already exists")
    rescue KeycloakAdmin::NotFoundError
      # Create realm
      create_realm
    end
  end
  
  private
  
  def create_realm
    realm_data = {
      id: @config.realm,
      realm: @config.realm,
      enabled: true,
      registrationAllowed: false,
      loginWithEmailAllowed: true,
      duplicateEmailsAllowed: false,
      resetCredentialsFlow: "reset-credentials",
      firstBrokerLoginFlow: "first-broker-login",
      browserFlow: "browser",
      registrationFlow: "registration",
      directGrantFlow: "direct-grant",
      clientAuthenticationFlow: "clients",
      dockerAuthenticationFlow: "docker-auth",
      attributes: {
        "frontendUrl" => [Rails.application.config.control_plane.url],
        "cors" => ["true"],
        "corsAllowedOrigins" => [Rails.application.config.control_plane.url, "*"]
      },
      themes: {
        loginTheme: "aurid",
        accountTheme: "aurid",
        adminTheme: "aurid",
        emailTheme: "aurid"
      },
      internationalizationEnabled: true,
      supportedLocales: ["en", "da", "de", "fr"],
      defaultLocale: "en",
      securityDefenses: {
        headers: {
          xFrameOptions: "DENY",
          contentSecurityPolicy: "frame-src 'self'; object-src 'none'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:",
          xContentTypeOptions: "nosniff",
          xRobotsTag: "none",
          xXssProtection: "1; mode=block",
          strictTransportSecurity: "max-age=31536000; includeSubDomains"
        },
        bruteForceProtection: {
          enabled: true,
          permanentLockout: false,
          maxLoginFailures: 5,
          waitIncrementSeconds: 60
        }
      }
    }
    
    @admin_client.create_realm(realm_data)
    
    # Create default client for Aurid
    create_aurid_client
    
    # Create default roles
    create_default_roles
    
    success(message: "Realm created successfully")
  end
  
  def create_aurid_client
    client_data = {
      clientId: "aurid-admin-console",
      name: "Aurid Admin Console",
      enabled: true,
      clientAuthenticatorType: "client-secret",
      secret: SecureRandom.urlsafe_base64(64),
      redirectUris: [
        "#{Rails.application.config.admin_console.url}/*",
        "http://localhost:3000/*"
      ],
      webOrigins: [
        Rails.application.config.admin_console.url,
        "http://localhost:3000"
      ],
      protocol: "openid-connect",
      publicClient: false,
      standardFlowEnabled: true,
      implicitFlowEnabled: false,
      directAccessGrantsEnabled: true,
      serviceAccountsEnabled: false,
      authorizationServicesEnabled: true,
      accessTokenLifespan: 3600,
      clientSessionIdleTimeout: 1800,
      clientSessionMaxLifespan: 3600,
      accessTokenLifespanForImplicitFlow: 900,
      attributes: {
        "oidc.ciba.grant.enabled" => ["false"],
        "backchannel.logout.revoke.offline.tokens" => ["false"],
        "backchannel.logout.session.required" => ["true"],
        "use.refresh.tokens" => ["true"],
        "use.jwt.oidc.credentials" => ["true"]
      }
    }
    
    @admin_client.create_client(client_data)
  end
  
  def create_default_roles
    # Create default roles in Keycloak
    default_roles = [
      { name: "super_admin", description: "Full access to all features and tenants" },
      { name: "admin", description: "Can manage tenant resources" },
      { name: "viewer", description: "Can view resources" },
      { name: "user", description: "Regular user with basic access" },
      { name: "guest", description: "Limited access" }
    ]
    
    default_roles.each do |role_data|
      begin
        @admin_client.create_role(role_data)
      rescue KeycloakAdmin::Error => e
        Rails.logger.warn "Failed to create role #{role_data[:name]}: #{e.message}"
      end
    end
  end
end
