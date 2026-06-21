# Tenant model for multi-tenancy support
# Represents an organization/customer using Aurid

class Tenant < ApplicationRecord
  has_many :users, dependent: :nullify
  has_many :domains, dependent: :destroy
  has_many :applications, dependent: :destroy
  has_many :audit_logs, dependent: :destroy
  has_many :settings, class_name: "TenantSetting", dependent: :destroy
  has_many :migration_jobs, dependent: :destroy
  has_many :identity_providers, dependent: :destroy
  
  # Status enum
  enum status: {
    pending: "pending",
    active: "active",
    suspended: "suspended",
    cancelled: "cancelled"
  }, _default: :pending
  
  # Tier enum
  enum tier: {
    free: "free",
    basic: "basic",
    professional: "professional",
    enterprise: "enterprise"
  }, _default: :free
  
  # Validations
  validates :name, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :domain, presence: true, uniqueness: true, 
            format: { with: URI::regexp(%w[http https]), allow_blank: true }
  validates :max_users, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_nil: true
  validates :billing_email, email: true, allow_nil: true
  
  # Callbacks
  before_validation :set_default_domain, on: :create
  before_create :generate_api_key
  
  # Scopes
  scope :by_status, ->(status) { where(status: status) }
  scope :active, -> { where(status: :active) }
  scope :ordered_by_name, -> { order(name: :asc) }
  scope :search_by_name, ->(query) { where("name ILIKE ?", "%#{query}%") if query.present? }
  
  # Attributes
  attribute :metadata, :jsonb, default: {}
  attribute :custom_branding, :jsonb, default: {}
  
  # Methods
  def display_name
    name
  end
  
  def user_count
    users.count
  end
  
  def active_user_count
    users.active.count
  end
  
  def can_add_users?
    max_users.nil? || user_count < max_users
  end
  
  def users_remaining
    return Float::INFINITY if max_users.nil?
    max_users - user_count
  end
  
  def billing_enabled?
    tier != "free"
  end
  
  def audit_logging_enabled?
    settings.find_by(key: "audit_logging_enabled")&.value == "true" || true
  end
  
  def ad_migration_enabled?
    settings.find_by(key: "ad_migration_enabled")&.value == "true" || tier.in?(["professional", "enterprise"])
  end
  
  def generate_new_api_key
    new_key = SecureRandom.urlsafe_base64(64)
    update(api_key: new_key)
    new_key
  end
  
  def api_key_digest
    return nil if api_key.blank?
    Digest::SHA256.hexdigest(api_key)
  end
  
  def api_key_digest=(digest)
    # Store the digest, not the raw key
    self[:api_key_digest] = digest
  end
  
  # Class methods
  def self.default
    find_or_create_by(name: "Default", domain: "aurid.io") do |tenant|
      tenant.status = :active
      tenant.tier = :enterprise
    end
  end
  
  def self.current
    Current.tenant || default
  end
  
  def self.current=(tenant)
    Current.tenant = tenant
  end
  
  private
  
  def set_default_domain
    self.domain ||= "#{name.parameterize}.aurid.io" if name.present?
  end
  
  def generate_api_key
    self.api_key = SecureRandom.urlsafe_base64(64)
    self.api_key_digest = Digest::SHA256.hexdigest(api_key)
  end
end
