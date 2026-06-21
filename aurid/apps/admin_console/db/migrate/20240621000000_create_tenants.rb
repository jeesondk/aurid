# Migration to create tenants table
# This is the first migration for the Admin Console

class CreateTenants < ActiveRecord::Migration[7.1]
  def change
    create_table :tenants, id: :uuid do |t|
      t.string :name, null: false
      t.string :domain, null: false
      t.string :description
      t.string :status, null: false, default: "pending"
      t.string :tier, null: false, default: "free"
      
      # Billing information
      t.string :billing_email
      t.string :billing_address
      t.string :billing_city
      t.string :billing_state
      t.string :billing_zip
      t.string :billing_country
      t.string :vat_number
      
      # API keys
      t.string :api_key
      t.string :api_key_digest
      
      # Limits
      t.integer :max_users
      t.integer :max_applications
      t.integer :max_domains
      
      # Metadata
      t.jsonb :metadata, default: {}
      t.jsonb :custom_branding, default: {}
      
      # Timestamps
      t.datetime :deleted_at
      t.timestamps
    end
    
    add_index :tenants, :name, unique: true
    add_index :tenants, :domain, unique: true
    add_index :tenants, :status
    add_index :tenants, :tier
    add_index :tenants, :api_key_digest, unique: true
    add_index :tenants, :deleted_at
    
    # Create the default tenant
    reversible do |dir|
      dir.up do
        default_tenant = Tenant.create!(
          name: "Default",
          domain: "aurid.io",
          status: :active,
          tier: :enterprise,
          description: "Default Aurid tenant"
        )
        puts "Created default tenant: #{default_tenant.id}"
      end
    end
  end
end
