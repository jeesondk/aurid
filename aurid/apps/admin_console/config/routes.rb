# Admin Console routes
Rails.application.routes.draw do
  # Health check endpoint
  get "/health", to: "health#index"
  get "/health/detailed", to: "health#detailed"
  
  # API documentation (if using Swagger/OpenAPI)
  # mount Rswag::Api::Engine => '/api-docs'
  # mount Rswag::Ui::Engine => '/api-docs-ui'
  
  # Devise authentication routes
  devise_for :users, 
             controllers: {
               sessions: "users/sessions",
               registrations: "users/registrations",
               passwords: "users/passwords",
               confirmations: "users/confirmations"
             },
             path: "auth",
             path_names: {
               sign_in: "login",
               sign_out: "logout",
               sign_up: "register"
             }
  
  # JWT authentication routes
  namespace :api do
    namespace :v1 do
      post "/auth/login", to: "auth#login"
      post "/auth/logout", to: "auth#logout"
      post "/auth/refresh", to: "auth#refresh"
      get "/auth/me", to: "auth#me"
      
      # MFA routes
      post "/auth/mfa/setup", to: "mfa#setup"
      post "/auth/mfa/verify", to: "mfa#verify"
      post "/auth/mfa/disable", to: "mfa#disable"
    end
  end
  
  # Main application routes
  root "dashboards#show"
  
  # Authentication required for most routes
  authenticate :user do
    # Dashboard
    get "/dashboard", to: "dashboards#show", as: :dashboard
    
    # Tenant management
    resources :tenants do
      member do
        get :switch
        post :impersonate
        post :stop_impersonating
      end
      
      resources :users, only: [:index, :new, :create, :edit, :update, :destroy] do
        member do
          post :resend_invitation
          post :suspend
          post :reactivate
          post :reset_password
        end
      end
      
      resources :settings, only: [:index, :update], controller: "tenant_settings"
      resources :domains, only: [:index, :new, :create, :destroy]
      resources :applications, only: [:index, :new, :create, :edit, :update, :destroy]
    end
    
    # User profile
    resource :profile, only: [:show, :edit, :update]
    
    # Admin routes (for super admins)
    namespace :admin do
      resources :tenants do
        member do
          post :approve
          post :suspend
          post :cancel
        end
      end
      
      resources :users do
        member do
          post :make_admin
          post :remove_admin
          post :make_super_admin
          post :remove_super_admin
        end
      end
      
      resources :roles
      resources :audit_logs, only: [:index, :show]
      resources :migration_jobs, only: [:index, :show, :create, :destroy]
      
      # System settings
      resource :system_settings, only: [:show, :edit, :update]
      
      # Keycloak management
      resources :keycloak do
        collection do
          post :sync
          post :setup_realm
          get :status
        end
      end
      
      # FreeIPA management
      resources :freeipa do
        collection do
          post :sync
          post :test_connection
          get :status
        end
      end
      
      # AD Migration
      resources :ad_migrations, only: [:new, :create, :show, :index] do
        member do
          post :start
          post :cancel
          get :download_report
        end
      end
    end
    
    # API routes
    namespace :api do
      namespace :v1 do
        # Tenant API
        resources :tenants, only: [:index, :show, :create, :update, :destroy] do
          member do
            get :users
            get :settings
            post :regenerate_api_key
          end
        end
        
        # User API
        resources :users, only: [:index, :show, :create, :update, :destroy] do
          member do
            post :suspend
            post :reactivate
            post :reset_password
          end
        end
        
        # Audit logs API
        resources :audit_logs, only: [:index, :show] do
          collection do
            get :export
          end
        end
        
        # Migration API
        resources :migrations, only: [:create, :show, :index] do
          member do
            post :start
            post :cancel
            get :status
          end
        end
        
        # Keycloak API
        namespace :keycloak do
          post :sync_users
          post :create_user
          post :update_user
          post :disable_user
          get :user_info
          get :realm_info
        end
        
        # FreeIPA API
        namespace :freeipa do
          post :sync_users
          post :create_user
          post :update_user
          post :disable_user
          get :user_info
          post :test_connection
        end
      end
    end
  end
  
  # Public routes (no authentication required)
  get "/invitation/:token", to: "invitations#show", as: :invitation
  post "/invitation/:token/accept", to: "invitations#accept", as: :accept_invitation
  
  # Password reset routes (Devise handles these, but we can customize)
  get "/password/reset", to: redirect("/auth/password/new")
  
  # API only routes (for service-to-service communication)
  namespace :internal do
    namespace :v1 do
      post "/webhooks/keycloak", to: "webhooks#keycloak"
      post "/webhooks/freeipa", to: "webhooks#freeipa"
      post "/webhooks/migration", to: "webhooks#migration"
    end
  end
  
  # Sidekiq web UI (for admins only)
  if Rails.env.development? || ENV["SIDEKIQ_WEB_ENABLED"] == "true"
    require "sidekiq/web"
    authenticate :user, ->(user) { user.super_admin? } do
      mount Sidekiq::Web => "/sidekiq"
    end
  end
  
  # Flipper UI for feature flags (for admins only)
  if defined?(Flipper) && (Rails.env.development? || ENV["FLIPPER_UI_ENABLED"] == "true")
    authenticate :user, ->(user) { user.super_admin? } do
      mount Flipper::UI.app(Flipper.instance) => "/flipper"
    end
  end
  
  # Administrate admin interface
  if defined?(Administrate)
    namespace :admin do
      resources :dashboard, only: [:index]
      
      namespace :administrate do
        resources :tenants
        resources :users
        resources :roles
        resources :audit_logs
        resources :migration_jobs
      end
    end
  end
  
  # Catch-all route for API
  namespace :api do
    namespace :v1 do
      match "*path", to: "application#not_found", via: :all
    end
  end
  
  # Catch-all route for web
  match "*path", to: "application#not_found", via: :all
end
