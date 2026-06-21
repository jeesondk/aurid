# User model for authentication and authorization
# Represents an administrator or end user of Aurid

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist
  
  # Associations
  belongs_to :tenant, optional: true
  has_many :sessions, dependent: :destroy
  has_many :audit_logs, foreign_key: :actor_id, dependent: :nullify
  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles
  has_many :mfa_devices, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :api_tokens, dependent: :destroy
  
  # Status enum
  enum status: {
    pending: "pending",
    active: "active",
    suspended: "suspended",
    disabled: "disabled"
  }, _default: :pending
  
  # Validations
  validates :email, presence: true, uniqueness: { case_sensitive: false },
            email: true
  validates :first_name, presence: true, length: { maximum: 100 }
  validates :last_name, presence: true, length: { maximum: 100 }
  validates :password, length: { minimum: 12 }, allow_nil: true
  
  # Callbacks
  before_validation :set_tenant, on: :create
  after_create :assign_default_role
  
  # Scopes
  scope :active, -> { where(status: :active) }
  scope :admins, -> { joins(:roles).where(roles: { name: "admin" }) }
  scope :by_tenant, ->(tenant) { where(tenant: tenant) }
  scope :ordered_by_name, -> { order(:first_name, :last_name) }
  scope :search_by_email, ->(query) { where("email ILIKE ?", "%#{query}%") if query.present? }
  scope :search_by_name, ->(query) { 
    where("first_name ILIKE ? OR last_name ILIKE ?", "%#{query}%", "%#{query}%") if query.present? 
  }
  
  # Attributes
  attribute :metadata, :jsonb, default: {}
  attribute :preferences, :jsonb, default: {}
  
  # Methods
  def full_name
    "#{first_name} #{last_name}".strip
  end
  
  def display_name
    full_name.presence || email
  end
  
  def admin?
    roles.where(name: "admin").exists?
  end
  
  def super_admin?
    roles.where(name: "super_admin").exists?
  end
  
  def tenant_admin?
    admin? && tenant_id.present?
  end
  
  def can_manage_tenant?(tenant)
    super_admin? || (tenant_admin? && tenant_id == tenant.id)
  end
  
  def can_manage_users?
    admin? || super_admin?
  end
  
  def can_manage_settings?
    admin? || super_admin?
  end
  
  def can_run_migrations?
    super_admin? || roles.where(name: "migration_admin").exists?
  end
  
  def mfa_enabled?
    mfa_devices.enabled.exists?
  end
  
  def mfa_required?
    tenant&.mfa_required? || super_admin?
  end
  
  def last_active_at
    sessions.maximum(:created_at) || updated_at
  end
  
  def active_sessions_count
    sessions.active.count
  end
  
  def deactivate_all_sessions!
    sessions.update_all(status: :revoked)
  end
  
  def generate_api_token(name = "Default")
    token = ApiToken.generate(self, name)
    api_tokens << token
    token
  end
  
  def jwt_payload
    {
      sub: id,
      email: email,
      tenant_id: tenant_id,
      roles: roles.pluck(:name),
      jti: SecureRandom.uuid,
      iat: Time.current.to_i
    }
  end
  
  # Class methods
  def self.current
    Current.user
  end
  
  def self.current=(user)
    Current.user = user
  end
  
  def self.super_admins
    joins(:roles).where(roles: { name: "super_admin" })
  end
  
  def self.find_by_jti(jti)
    # Find user by JWT ID (for revocation)
    # This would need to be implemented based on your JWT storage strategy
    # For now, we'll just return nil as JWTs are stateless
    nil
  end
  
  private
  
  def set_tenant
    self.tenant ||= Tenant.default if tenant_id.blank?
  end
  
  def assign_default_role
    # Assign viewer role by default
    role = Role.find_or_create_by(name: "viewer", description: "Can view resources")
    user_roles.create(role: role) unless roles.exists?
    
    # If this is the first user for the tenant, make them admin
    if tenant.users.count == 1
      admin_role = Role.find_or_create_by(name: "admin", description: "Can manage tenant resources")
      user_roles.create(role: admin_role)
    end
  end
end
