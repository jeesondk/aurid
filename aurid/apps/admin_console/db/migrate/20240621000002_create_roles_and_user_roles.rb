# Migration to create roles and user_roles join table

class CreateRolesAndUserRoles < ActiveRecord::Migration[7.1]
  def change
    # Create roles table
    create_table :roles, id: :uuid do |t|
      t.string :name, null: false
      t.string :description
      t.string :resource_type
      t.uuid :resource_id
      
      # Permissions (stored as JSON for flexibility)
      t.jsonb :permissions, default: []
      
      # Scopes
      t.boolean :global, default: false
      t.boolean :system, default: false
      
      # Timestamps
      t.datetime :deleted_at
      t.timestamps
    end
    
    add_index :roles, :name, unique: true
    add_index :roles, [:resource_type, :resource_id]
    add_index :roles, :global
    add_index :roles, :system
    add_index :roles, :deleted_at
    
    # Create user_roles join table
    create_table :user_roles, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.references :role, type: :uuid, null: false, foreign_key: true
      
      # Additional attributes for the join
      t.uuid :assigned_by_id
      t.datetime :expires_at
      
      t.timestamps
    end
    
    add_index :user_roles, [:user_id, :role_id], unique: true
    add_index :user_roles, :assigned_by_id
    add_index :user_roles, :expires_at
    
    # Create default roles if they don't exist
    reversible do |dir|
      dir.up do
        # System roles
        system_roles = [
          { name: "super_admin", description: "Full access to all features and tenants", system: true, global: true },
          { name: "admin", description: "Can manage tenant resources", system: true, global: true },
          { name: "viewer", description: "Can view resources", system: true, global: true },
          { name: "user", description: "Regular user with basic access", system: true, global: true },
          { name: "guest", description: "Limited access", system: true, global: true }
        ]
        
        system_roles.each do |role_attrs|
          Role.find_or_create_by!(name: role_attrs[:name]) do |role|
            role.assign_attributes(role_attrs)
          end
        end
        
        # Identity management roles
        identity_roles = [
          { name: "identity_admin", description: "Can manage identity providers and users", system: false, global: false },
          { name: "migration_admin", description: "Can run AD migration jobs", system: false, global: false },
          { name: "audit_admin", description: "Can view and export audit logs", system: false, global: false },
          { name: "billing_admin", description: "Can manage billing and subscriptions", system: false, global: false }
        ]
        
        identity_roles.each do |role_attrs|
          Role.find_or_create_by!(name: role_attrs[:name]) do |role|
            role.assign_attributes(role_attrs)
          end
        end
        
        puts "Created default roles"
      end
    end
  end
end
