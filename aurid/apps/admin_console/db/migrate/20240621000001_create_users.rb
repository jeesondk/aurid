# Migration to create users table

class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users, id: :uuid do |t|
      t.references :tenant, type: :uuid, foreign_key: true
      
      # Authentication
      t.string :email, null: false
      t.string :encrypted_password, null: false
      t.string :password_digest
      
      # Personal information
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :phone
      t.string :job_title
      t.string :department
      
      # Profile
      t.string :avatar_url
      t.string :timezone, default: "Copenhagen"
      t.string :locale, default: "en"
      
      # Status
      t.string :status, null: false, default: "pending"
      
      # Authentication tokens
      t.string :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string :unconfirmed_email
      
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      
      t.string :remember_created_at
      
      # Lockable
      t.string :unlock_token
      t.integer :failed_attempts, default: 0
      t.datetime :locked_at
      t.datetime :last_locked_at
      
      # Trackable
      t.integer :sign_in_count, default: 0
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string :current_sign_in_ip
      t.string :last_sign_in_ip
      
      # JWT authentication
      t.string :jwt_token
      t.datetime :jwt_token_expires_at
      
      # MFA
      t.boolean :mfa_enabled, default: false
      t.string :mfa_secret
      t.string :mfa_recovery_codes, array: true, default: []
      
      # Preferences
      t.jsonb :preferences, default: {}
      t.jsonb :metadata, default: {}
      
      # Timestamps
      t.datetime :deleted_at
      t.timestamps
    end
    
    add_index :users, :email, unique: true
    add_index :users, :tenant_id
    add_index :users, :confirmation_token, unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :unlock_token, unique: true
    add_index :users, :status
    add_index :users, :deleted_at
    add_index :users, :jwt_token
    add_index :users, [:tenant_id, :email], unique: true
    
    # Create the first super admin user
    reversible do |dir|
      dir.up do
        default_tenant = Tenant.find_by(name: "Default") || Tenant.first
        
        if default_tenant
          # Create super admin role
          super_admin_role = Role.find_or_create_by!(
            name: "super_admin",
            description: "Full access to all features and tenants"
          )
          
          admin_role = Role.find_or_create_by!(
            name: "admin",
            description: "Can manage tenant resources"
          )
          
          viewer_role = Role.find_or_create_by!(
            name: "viewer",
            description: "Can view resources"
          )
          
          # Create default super admin user
          super_admin = User.create!(
            email: "admin@aurid.io",
            first_name: "Super",
            last_name: "Admin",
            password: ENV["DEFAULT_ADMIN_PASSWORD"] || SecureRandom.hex(16),
            password_confirmation: ENV["DEFAULT_ADMIN_PASSWORD"] || SecureRandom.hex(16),
            status: :active,
            confirmed_at: Time.current,
            tenant: default_tenant
          )
          
          # Assign roles
          super_admin.user_roles.create!(role: super_admin_role)
          super_admin.user_roles.create!(role: admin_role)
          super_admin.user_roles.create!(role: viewer_role)
          
          puts "Created super admin user: #{super_admin.email}"
          puts "Password: #{ENV["DEFAULT_ADMIN_PASSWORD"] || "(randomly generated)"}"
        end
      end
    end
  end
end
