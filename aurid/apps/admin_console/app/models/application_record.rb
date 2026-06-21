# Base application record for Admin Console
# All models inherit from this

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  
  # Use UUID as primary key for all models
  self.primary_key = :id
  
  # Connect to the admin_console database
  connects_to database: { writing: :primary, reading: :primary }
  
  # Default scope for soft deletion support
  default_scope { where(deleted_at: nil) }
  
  # Soft deletion support
  def self.actives
    where(deleted_at: nil)
  end
  
  def self.deleted
    where.not(deleted_at: nil)
  end
  
  def soft_delete
    update(deleted_at: Time.current)
  end
  
  def restore
    update(deleted_at: nil)
  end
  
  def deleted?
    deleted_at.present?
  end
  
  def active?
    deleted_at.nil?
  end
end
