# Base service class for Aurid
# All services inherit from this

class BaseService
  # Result object for service operations
  class Result
    attr_reader :success, :data, :error, :message, :status
    
    def initialize(success:, data: nil, error: nil, message: nil, status: nil)
      @success = success
      @data = data
      @error = error
      @message = message
      @status = status || (success ? :ok : :error)
    end
    
    def success?
      @success
    end
    
    def failure?
      !@success
    end
    
    def to_h
      result = { success: @success }
      result[:data] = @data if @data.present?
      result[:error] = @error if @error.present?
      result[:message] = @message if @message.present?
      result[:status] = @status if @status.present?
      result
    end
    
    def to_json
      to_h.to_json
    end
  end
  
  # Error classes
  class ServiceError < StandardError
    attr_reader :code, :status, :details
    
    def initialize(message = nil, code: nil, status: nil, details: nil)
      super(message)
      @code = code || :service_error
      @status = status || :bad_request
      @details = details
    end
    
    def to_h
      {
        error: @code.to_s,
        message: message,
        status: @status,
        details: @details
      }.compact
    end
  end
  
  class ValidationError < ServiceError
    def initialize(message = "Validation failed", errors: nil)
      super(message, code: :validation_error, status: :unprocessable_entity, details: errors)
    end
  end
  
  class NotFoundError < ServiceError
    def initialize(resource = "Resource", id = nil)
      message = "#{resource} not found"
      message += " with ID: #{id}" if id
      super(message, code: :not_found, status: :not_found)
    end
  end
  
  class UnauthorizedError < ServiceError
    def initialize(message = "Unauthorized")
      super(message, code: :unauthorized, status: :unauthorized)
    end
  end
  
  class ForbiddenError < ServiceError
    def initialize(message = "Forbidden")
      super(message, code: :forbidden, status: :forbidden)
    end
  end
  
  class RateLimitError < ServiceError
    def initialize(message = "Rate limit exceeded")
      super(message, code: :rate_limit_exceeded, status: :too_many_requests)
    end
  end
  
  # Class methods
  class << self
    # Call the service with automatic error handling
    def call(*args, **kwargs)
      new(*args, **kwargs).call
    end
    
    # Call the service and raise on error
    def call!(*args, **kwargs)
      result = call(*args, **kwargs)
      raise ServiceError.new(result.error, code: result.status) unless result.success?
      result
    end
  end
  
  # Instance methods
  def initialize(*args, **kwargs)
    @args = args
    @kwargs = kwargs
    setup
  end
  
  def call
    execute
  rescue ServiceError => e
    Result.new(success: false, error: e.code, message: e.message, status: e.status, data: e.details)
  rescue StandardError => e
    handle_error(e)
  end
  
  def setup
    # Override in subclasses for setup
  end
  
  def execute
    raise NotImplementedError, "Subclasses must implement #execute"
  end
  
  def handle_error(error)
    Rails.logger.error "Service error: #{error.class} - #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    
    Result.new(
      success: false,
      error: :internal_server_error,
      message: "An unexpected error occurred",
      status: :internal_server_error
    )
  end
  
  # Helper methods
  def success(data: nil, message: nil)
    Result.new(success: true, data: data, message: message)
  end
  
  def failure(error: nil, message: nil, status: nil, data: nil)
    Result.new(success: false, error: error, message: message, status: status, data: data)
  end
  
  def validate!(record)
    return true if record.valid?
    raise ValidationError.new("Validation failed", errors: record.errors.full_messages)
  end
  
  def find_record!(model, id)
    record = model.find_by(id: id)
    raise NotFoundError.new(model.name, id) if record.nil?
    record
  end
  
  def authorize!(condition, message = "Not authorized")
    raise ForbiddenError.new(message) unless condition
  end
  
  def authorize_admin!(user)
    authorize!(user.admin? || user.super_admin?, "You must be an admin")
  end
  
  def authorize_super_admin!(user)
    authorize!(user.super_admin?, "You must be a super admin")
  end
end
