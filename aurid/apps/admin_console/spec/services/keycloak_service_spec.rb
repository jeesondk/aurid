# Keycloak Service Tests

require "rails_helper"

RSpec.describe KeycloakService, type: :service do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, :super_admin, tenant: tenant) }
  let(:service) { described_class.new(user: user, tenant: tenant) }

  describe "BaseService" do
    describe "Result" do
      it "creates success result" do
        result = KeycloakService::Result.new(success: true, data: { test: "value" })
        expect(result.success?).to be true
        expect(result.failure?).to be false
        expect(result.data).to eq({ test: "value" })
      end

      it "creates failure result" do
        result = KeycloakService::Result.new(
          success: false,
          error: :test_error,
          message: "Test message",
          status: :bad_request
        )
        expect(result.success?).to be false
        expect(result.failure?).to be true
        expect(result.error).to eq(:test_error)
        expect(result.message).to eq("Test message")
        expect(result.status).to eq(:bad_request)
      end

      it "converts to hash" do
        result = KeycloakService::Result.new(
          success: true,
          data: { test: "value" },
          message: "Success"
        )
        hash = result.to_h
        expect(hash[:success]).to be true
        expect(hash[:data]).to eq({ test: "value" })
        expect(hash[:message]).to eq("Success")
      end

      it "converts to JSON" do
        result = KeycloakService::Result.new(success: true, data: { test: "value" })
        json = result.to_json
        expect(json).to be_a(String)
        parsed = JSON.parse(json)
        expect(parsed["success"]).to be true
      end
    end

    describe "ServiceError" do
      it "creates error with defaults" do
        error = KeycloakService::ServiceError.new("Test error")
        expect(error.message).to eq("Test error")
        expect(error.code).to eq(:service_error)
        expect(error.status).to eq(:bad_request)
      end

      it "creates error with custom values" do
        error = KeycloakService::ServiceError.new(
          "Custom error",
          code: :custom_error,
          status: :forbidden,
          details: { field: "value" }
        )
        expect(error.message).to eq("Custom error")
        expect(error.code).to eq(:custom_error)
        expect(error.status).to eq(:forbidden)
        expect(error.details).to eq({ field: "value" })
      end

      it "converts to hash" do
        error = KeycloakService::ServiceError.new(
          "Test error",
          code: :test_error,
          status: :bad_request
        )
        hash = error.to_h
        expect(hash[:error]).to eq("test_error")
        expect(hash[:message]).to eq("Test error")
        expect(hash[:status]).to eq(:bad_request)
      end
    end

    describe "ValidationError" do
      it "creates validation error" do
        error = KeycloakService::ValidationError.new("Validation failed", errors: ["Error 1", "Error 2"])
        expect(error.code).to eq(:validation_error)
        expect(error.status).to eq(:unprocessable_entity)
        expect(error.details).to eq(["Error 1", "Error 2"])
      end
    end

    describe "NotFoundError" do
      it "creates not found error" do
        error = KeycloakService::NotFoundError.new("User", "123")
        expect(error.message).to eq("User not found with ID: 123")
        expect(error.code).to eq(:not_found)
        expect(error.status).to eq(:not_found)
      end
    end

    describe "UnauthorizedError" do
      it "creates unauthorized error" do
        error = KeycloakService::UnauthorizedError.new("Not authorized")
        expect(error.message).to eq("Not authorized")
        expect(error.code).to eq(:unauthorized)
        expect(error.status).to eq(:unauthorized)
      end
    end

    describe "ForbiddenError" do
      it "creates forbidden error" do
        error = KeycloakService::ForbiddenError.new("Access denied")
        expect(error.message).to eq("Access denied")
        expect(error.code).to eq(:forbidden)
        expect(error.status).to eq(:forbidden)
      end
    end

    describe "RateLimitError" do
      it "creates rate limit error" do
        error = KeycloakService::RateLimitError.new("Too many requests")
        expect(error.message).to eq("Too many requests")
        expect(error.code).to eq(:rate_limit_exceeded)
        expect(error.status).to eq(:too_many_requests)
      end
    end
  end

  describe "BaseService methods" do
    let(:base_service) { KeycloakService.new }

    describe "success" do
      it "creates success result" do
        result = base_service.success(data: { test: "value" }, message: "Success")
        expect(result.success?).to be true
        expect(result.data).to eq({ test: "value" })
        expect(result.message).to eq("Success")
      end
    end

    describe "failure" do
      it "creates failure result" do
        result = base_service.failure(
          error: :test_error,
          message: "Test message",
          status: :bad_request
        )
        expect(result.success?).to be false
        expect(result.error).to eq(:test_error)
      end
    end

    describe "validate!" do
      it "returns true for valid record" do
        user = build(:user)
        expect(base_service.validate!(user)).to be true
      end

      it "raises ValidationError for invalid record" do
        user = build(:user, email: "")
        expect { base_service.validate!(user) }.to raise_error(KeycloakService::ValidationError)
      end
    end

    describe "find_record!" do
      it "returns record when found" do
        user = create(:user)
        expect(base_service.find_record!(User, user.id)).to eq(user)
      end

      it "raises NotFoundError when not found" do
        expect { base_service.find_record!(User, SecureRandom.uuid) }
          .to raise_error(KeycloakService::NotFoundError)
      end
    end

    describe "authorize!" do
      it "returns true when authorized" do
        expect { base_service.authorize!(true) }.not_to raise_error
      end

      it "raises ForbiddenError when not authorized" do
        expect { base_service.authorize!(false) }
          .to raise_error(KeycloakService::ForbiddenError)
      end

      it "uses custom message" do
        expect { base_service.authorize!(false, "Custom message") }
          .to raise_error(KeycloakService::ForbiddenError, "Custom message")
      end
    end

    describe "authorize_admin!" do
      it "returns true for admin user" do
        admin = build(:user, :admin)
        expect { base_service.authorize_admin!(admin) }.not_to raise_error
      end

      it "raises ForbiddenError for non-admin user" do
        user = build(:user)
        expect { base_service.authorize_admin!(user) }
          .to raise_error(KeycloakService::ForbiddenError)
      end
    end

    describe "authorize_super_admin!" do
      it "returns true for super admin user" do
        super_admin = build(:user, :super_admin)
        expect { base_service.authorize_super_admin!(super_admin) }.not_to raise_error
      end

      it "raises ForbiddenError for non-super-admin user" do
        user = build(:user, :admin)
        expect { base_service.authorize_super_admin!(user) }
          .to raise_error(KeycloakService::ForbiddenError)
      end
    end
  end

  describe "class methods" do
    describe ".call" do
      it "calls service and returns result" do
        result = KeycloakService.call
        expect(result).to be_a(KeycloakService::Result)
        expect(result.success?).to be true
      end
    end

    describe ".call!" do
      it "calls service and returns result" do
        result = KeycloakService.call!
        expect(result).to be_a(KeycloakService::Result)
        expect(result.success?).to be true
      end

      it "raises on error" do
        # Create a service that always fails
        failing_service = Class.new(KeycloakService) do
          def execute
            failure(error: :test_error, message: "Test error")
          end
        end

        expect { failing_service.call! }
          .to raise_error(KeycloakService::ServiceError, /Test error/)
      end
    end
  end

  describe "AdminClient" do
    let(:config) { Rails.application.config.keycloak }
    let(:client) { KeycloakService::AdminClient.new(config) }

    describe "initialization" do
      it "initializes with config" do
        expect(client.config).to eq(config)
      end

      it "builds client" do
        expect(client.instance_variable_get(:@client)).to be_a(KeycloakAdmin::Client)
      end
    end

    describe "test_connection" do
      it "tests connection to Keycloak" do
        # This would normally connect to Keycloak
        # For testing, we'll mock the client
        allow_any_instance_of(KeycloakAdmin::Client).to receive(:get_realms).and_return([])
        
        result = client.test_connection
        expect(result).to be true
      end

      it "returns false on connection failure" do
        allow_any_instance_of(KeycloakAdmin::Client).to receive(:get_realms).and_raise(StandardError.new("Connection failed"))
        
        result = client.test_connection
        expect(result).to be false
      end
    end
  end

  describe "KeycloakUserSyncService" do
    let(:user) { create(:user, :confirmed) }
    let(:service) { KeycloakUserSyncService.new(user: user, tenant: tenant) }

    describe "execute" do
      it "returns error when user is nil" do
        service = KeycloakUserSyncService.new(user: nil, tenant: tenant)
        result = service.call
        expect(result.success?).to be false
        expect(result.error).to eq(:user_required)
      end

      it "syncs user to Keycloak" do
        # Mock the admin client
        admin_client = instance_double(KeycloakService::AdminClient)
        allow(KeycloakService::AdminClient).to receive(:new).and_return(admin_client)
        
        # Mock user not found in Keycloak
        allow(admin_client).to receive(:get_user_by_username).and_raise(KeycloakAdmin::NotFoundError.new("Not found"))
        
        # Mock user creation
        allow(admin_client).to receive(:create_user).and_return({ id: "123" })
        
        result = service.call
        expect(result.success?).to be true
        expect(result.data[:synced]).to be true
      end

      it "updates existing user in Keycloak" do
        admin_client = instance_double(KeycloakService::AdminClient)
        allow(KeycloakService::AdminClient).to receive(:new).and_return(admin_client)
        
        # Mock user found in Keycloak
        keycloak_user = { id: "123", username: user.email }
        allow(admin_client).to receive(:get_user_by_username).and_return(keycloak_user)
        
        # Mock user update
        allow(admin_client).to receive(:update_user).and_return(keycloak_user)
        
        result = service.call
        expect(result.success?).to be true
      end

      it "handles sync errors" do
        admin_client = instance_double(KeycloakService::AdminClient)
        allow(KeycloakService::AdminClient).to receive(:new).and_return(admin_client)
        
        # Mock connection error
        allow(admin_client).to receive(:get_user_by_username).and_raise(StandardError.new("Connection failed"))
        
        result = service.call
        expect(result.success?).to be false
        expect(result.error).to eq(:sync_failed)
      end
    end
  end

  describe "KeycloakGroupSyncService" do
    let(:role) { create(:role, :admin) }
    let(:service) { KeycloakGroupSyncService.new(group: role, tenant: tenant) }

    describe "execute" do
      it "returns error when group is nil" do
        service = KeycloakGroupSyncService.new(group: nil, tenant: tenant)
        result = service.call
        expect(result.success?).to be false
        expect(result.error).to eq(:group_required)
      end

      it "syncs group to Keycloak" do
        admin_client = instance_double(KeycloakService::AdminClient)
        allow(KeycloakService::AdminClient).to receive(:new).and_return(admin_client)
        
        # Mock group not found in Keycloak
        allow(admin_client).to receive(:get_group_by_name).and_raise(KeycloakAdmin::NotFoundError.new("Not found"))
        
        # Mock group creation
        allow(admin_client).to receive(:create_group).and_return({ id: "123" })
        
        result = service.call
        expect(result.success?).to be true
        expect(result.data[:synced]).to be true
      end
    end
  end

  describe "KeycloakFullSyncService" do
    let(:tenant) { create(:tenant) }
    let(:service) { KeycloakFullSyncService.new(tenant: tenant) }

    describe "execute" do
      it "syncs all users and groups" do
        create_list(:user, 3, tenant: tenant)
        
        admin_client = instance_double(KeycloakService::AdminClient)
        allow(KeycloakService::AdminClient).to receive(:new).and_return(admin_client)
        
        # Mock user sync
        allow(admin_client).to receive(:get_user_by_username).and_raise(KeycloakAdmin::NotFoundError.new("Not found"))
        allow(admin_client).to receive(:create_user).and_return({ id: "123" })
        
        # Mock group sync
        allow(admin_client).to receive(:get_group_by_name).and_raise(KeycloakAdmin::NotFoundError.new("Not found"))
        allow(admin_client).to receive(:create_group).and_return({ id: "456" })
        
        result = service.call
        expect(result.success?).to be true
        expect(result.data[:synced_users]).to eq(3)
      end
    end
  end

  describe "KeycloakSetupService" do
    let(:tenant) { create(:tenant) }
    let(:service) { KeycloakSetupService.new(tenant: tenant) }

    describe "execute" do
      it "creates realm if it doesn't exist" do
        admin_client = instance_double(KeycloakService::AdminClient)
        allow(KeycloakService::AdminClient).to receive(:new).and_return(admin_client)
        
        # Mock realm not found
        allow(admin_client).to receive(:get_realm).and_raise(KeycloakAdmin::NotFoundError.new("Not found"))
        
        # Mock realm creation
        allow(admin_client).to receive(:create_realm).and_return({ id: "aurid" })
        allow(admin_client).to receive(:create_client).and_return({ clientId: "aurid-admin-console" })
        allow(admin_client).to receive(:create_role).and_return({ name: "admin" })
        
        result = service.call
        expect(result.success?).to be true
      end

      it "returns existing realm" do
        admin_client = instance_double(KeycloakService::AdminClient)
        allow(KeycloakService::AdminClient).to receive(:new).and_return(admin_client)
        
        # Mock realm found
        realm = { id: "aurid", realm: "aurid" }
        allow(admin_client).to receive(:get_realm).and_return(realm)
        
        result = service.call
        expect(result.success?).to be true
        expect(result.data[:realm]).to eq(realm)
      end
    end
  end
end
