# Devise configuration for Admin Console
# Use this hook to configure devise mailer, warden hooks and so forth.
# Many of these configuration options can be set straight in your model.

Devise.setup do |config|
  # The secret key used by Devise. Devise uses this key to generate
  # random tokens. Changing this key will render invalid all existing
  # confirmation, reset password and unlock tokens in the database.
  # Rotate this key if you want to invalidate all existing tokens.
  config.secret_key = ENV["DEVISE_SECRET_KEY"] || Rails.application.credentials.devise_secret_key

  # ==> Mailer Configuration
  # Configure the e-mail address which will be shown in Devise::Mailer,
  # note that it will be overwritten if you use your own mailer class
  # with default `from` parameter.
  config.mailer_sender = ENV.fetch("DEVISE_MAILER_SENDER", "noreply@aurid.io")

  # Configure the class responsible to send e-mails.
  config.parent_mailer = ActionMailer::Base

  # ==> ORM configuration
  # Load and configure the ORM. Supports :active_record (default) and
  # :mongoid (bson_ext recommended) by default. Other ORMs may be
  # available as additional gems.
  require "devise/orm/active_record"

  # ==> Configuration for any authentication mechanism
  # Configure which keys are used when authenticating a user. The default is
  # just :email. You can configure it to use [:username, :subdomain], so for
  # authenticating a user, both parameters are required. Remember that those
  # parameters are used only when authenticating and not when retrieving from
  # session. If you need permissions, you should implement that in a before filter.
  # You can also supply a hash where the value is a boolean determining whether
  # or not authentication should be aborted when the value is not present.
  config.authentication_keys = [:email]

  # Configure parameters from the request object used for authentication. Each entry
  # given should be a request method and it will automatically be passed to the
  # find_for_authentication method and considered in your model lookup. Any
  # default can be overridden in your model.
  config.request_keys = []

  # Tell if authentication through request.params is enabled. True by default.
  # It can be set to an array that will enable params authentication only for the
  # given strategies, for example, `config.params_authenticatable = [:database]` will
  # enable it only for database (email + password) authentication.
  config.params_authenticatable = true

  # ==> Configuration for :database_authenticatable
  # For bcrypt, this is the cost for hashing the password and defaults to 12.
  # If using other algorithms, it sets how many times you want the password
  # to be hashed. The higher the number of stretches, the more secure the
  # hashing is, but its slowdown for each attempt is exponential.
  #
  # Example:
  #   config.stretches = 20
  #
  # This option can be overridden in your model.
  config.stretches = Rails.env.test? ? 1 : 12

  # Setup a pepper to generate the encrypted password.
  # By default it's the application's secret key base, but you can change it.
  # When using multiple authentication strategies, you should call
  # `secret_key_base` on the warder instance after each request.
  config.pepper = ENV["DEVISE_PEPPER"] || Rails.application.credentials.devise_pepper

  # Send a notification to the original email when the user's email is changed.
  config.send_email_changed_notification = true

  # Send a notification email when the user's password is changed.
  config.send_password_change_notification = true

  # ==> Configuration for :confirmable
  # A period that the user is allowed to access the website even without
  # confirming their account. For instance, if set to 2.days, the user will be
  # able to access the website for two days without confirming their account,
  # access will be blocked just in the third day.
  # You can also set it to nil, which will allow the user to access the website
  # without confirming their account.
  config.allow_unconfirmed_access_for = 7.days

  # A period that the user is allowed to confirm their account before their
  # token becomes invalid. For example, if set to 3.days, the user can confirm
  # their account within 3 days after the mail was sent, if the period has
  # expired, a new confirmation link will be sent.
  config.confirm_within = 7.days

  # If true, requires any email changes to be confirmed (by default true).
  # If the user's e-mail address is changed, a confirmation e-mail will be
  # sent to their new address, and the change will not be effective until
  # they confirm it.
  config.reconfirmable = true

  # Defines which key will be used when confirming an account
  config.confirmation_keys = [:email]

  # ==> Configuration for :rememberable
  # The time the user will be remembered without asking for credentials again.
  config.remember_for = 30.days

  # Invalidates all the remember me tokens when the user signs out.
  config.expire_all_remember_me_on_sign_out = true

  # If true, extends the user's remember period when remembered via cookie.
  config.extend_remember_period = false

  # Options to be passed to the created cookie. For instance, you can set
  # secure: Rails.env.production? to have the cookie only sent through HTTPS
  # in production. Default is {}.
  config.rememberable_options = { secure: Rails.env.production? }

  # ==> Configuration for :validatable
  # Range for password length. Default is 8..128.
  config.password_length = 12..128

  # Email regex used to validate email formats. It simply asserts that
  # one (and only one) @ exists in the given string. This is mainly
  # to give user feedback and not to assert the e-mail validity.
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/

  # ==> Configuration for :timeoutable
  # The time you want to timeout the user session without activity. After this
  # time the user will be asked for credentials again. Default is 30 minutes.
  config.timeout_in = 30.minutes

  # If true, the user will be asked for credentials again after the configured
  # time (above). If false, the session will be expired after the time
  # passes. Default is true.
  config.expire_after_timeout = true

  # ==> Configuration for :lockable
  # Defines which strategy will be used to lock an account.
  # :failed_attempts = Locks an account after a number of failed attempts.
  # :none            = No lock strategy. You should handle it yourself.
  config.lock_strategy = :failed_attempts

  # Defines which key will be used when locking and unlocking an account
  config.unlock_keys = [:email]

  # Defines which strategy will be used to unlock an account.
  # :email = Sends an unlock link to the user email
  # :time  = Re-enables login after a certain amount of time (see :unlock_in below)
  # :both  = Enables both strategies
  # :none  = No unlock strategy. You should handle it yourself.
  config.unlock_strategy = :both

  # Number of authentication tries before locking an account if lock_strategy
  # is failed attempts.
  config.maximum_attempts = 5

  # Time interval to unlock the account if :time is enabled as unlock_strategy.
  config.unlock_in = 1.hour

  # Warn on the last attempt before the account is locked.
  config.last_attempt_warning = true

  # ==> Configuration for :recoverable
  # Time interval you can reset your password with a reset password key.
  # Don't put a too small interval, like 1.minute, because of possible
  # clock differences between the server and the user's client.
  config.reset_password_within = 6.hours

  # When set to false, does not sign a user in automatically after their password is
  # reset. Default is true, so a user is signed in automatically after a reset.
  config.sign_in_after_reset_password = true

  # ==> Configuration for :encryptable
  # Allow Devise to use an encrypted version of the password already in the DB.
  # When set to true, Devise will use the encrypted password from the database
  # and will try to decrypt it using the same algorithm and key used for
  # encryption. This is useful if you need to change the encryption algorithm
  # or key.
  config.encryptor = :bcrypt

  # ==> Scopes configuration
  # Turn scoped views on. Before rendering "sessions/new", it will first check for
  # "users/sessions/new". It's turned off by default because it's slower if you
  # are using only default views.
  config.scoped_views = true

  # Configure the default scope given to Warden. By default it's the first
  # devise role declared in your routes (usually :user).
  config.default_scope = :user

  # Set this configuration to false if you want to be able to sign out
  # from any scope. By default, Devise will check if the scope is under
  # the warden scope before trying to sign out. It will raise a Warden::Unauthorized
  # exception if the scope is not under warden.
  config.allow_unconfirmed_access_for_all_scopes = false

  # ==> Configuration for :jwt_authenticatable
  # Configure JWT settings for API authentication
  config.jwt do |jwt|
    # Secret key used to sign JWT tokens
    jwt.secret = ENV["JWT_SECRET_KEY"] || Rails.application.credentials.jwt_secret_key
    
    # Algorithm used to sign tokens
    jwt.signing_algorithm = "HS256"
    
    # Token expiration time
    jwt.expiration_time = 1.hour.to_i
    
    # Refresh token expiration time
    jwt.refresh_expiration_time = 7.days.to_i
    
    # Issuer claim
    jwt.issuer = "aurid-admin-console"
    
    # Audience claim
    jwt.audience = "aurid-api"
    
    # Key used to identify the token in the request
    jwt.request_header = "Authorization"
    
    # Prefix for the token in the header (e.g., "Bearer <token>")
    jwt.request_header_prefix = "Bearer "
    
    # Strategy for revoking tokens
    jwt.revocation_strategy = JwtDenylist
    
    # Store the JWT in the database for revocation
    jwt.store_in_database = true
    
    # Claims to include in the JWT
    jwt.payload do |user|
      {
        sub: user.id,
        email: user.email,
        tenant_id: user.tenant_id,
        roles: user.roles.pluck(:name),
        jti: SecureRandom.uuid,
        iat: Time.current.to_i,
        exp: 1.hour.from_now.to_i
      }
    end
    
    # Dispatch requests to the JWT controller
    jwt.dispatch_requests = [
      ["POST", "/api/v1/auth/login"],
      ["POST", "/api/v1/auth/logout"],
      ["POST", "/api/v1/auth/refresh"]
    ]
    
    # Revocation settings
    jwt.revocation_requests = [
      ["DELETE", "/api/v1/auth/logout"]
    ]
  end

  # ==> Warden configuration
  # If you want to use other strategies, that are not supported by Devise, or
  # change the failure app, you can configure them inside the Warden block.
  config.warden do |manager|
    # Custom failure app for API requests
    manager.failure_app = UnauthorizedController
    
    # Custom strategies
    manager.strategies.add(:jwt, JwtStrategy)
    
    # Default strategies
    manager.default_strategies(scope: :user).unshift :jwt
  end

  # ==> Navigation configuration
  # Lists the formats that should be treated as navigational. Formats like
  # :html, should redirect to the sign in page when the user is not signed in
  # and a request is made. If you have any additional navigational formats,
  # like :iphone or :mobile, you should add them to the navigational formats lists.
  config.navigational_formats = ["*/*", :html, :turbo_stream]

  # The scope to be used to check for existing users.
  config.scope = :user

  # ==> OmniAuth configuration
  # Add a new OmniAuth provider. Check the wiki for more information on setting
  # up on your models and hooks.
  # config.omniauth :github, 'APP_ID', 'APP_SECRET', scope: "user:email"

  # ==> Callbacks configuration
  # If you have any callback that should be invoked for any user, you can
  # define it here. For example, if users should be sent to a specific
  # page on sign out, you can specify it below.
  # config.sign_out_via = :delete
end

# Custom JWT revocation strategy
class JwtDenylist
  def self.jwt_revoked?(payload, user)
    # Check if the JWT has been revoked
    # This can be implemented by storing revoked JWTs in the database
    JwtDenylist.exists?(jti: payload["jti"])
  end
  
  def self.jwt_revoke(payload, user)
    # Revoke the JWT by storing it in the denylist
    JwtDenylist.create!(jti: payload["jti"], expires_at: payload["exp"])
  end
end

# Custom Warden strategy for JWT authentication
class JwtStrategy < Warden::Strategies::Base
  def valid?
    # Check if the request has an Authorization header
    request.headers["Authorization"].present? &&
      request.headers["Authorization"].start_with?("Bearer ")
  end
  
  def authenticate!
    # Extract the token from the Authorization header
    token = request.headers["Authorization"].split(" ").last
    
    # Decode and verify the JWT
    payload = JWT.decode(token, Devise.jwt.secret, true, {
      algorithm: Devise.jwt.signing_algorithm,
      iss: Devise.jwt.issuer,
      aud: Devise.jwt.audience,
      verify_iss: true,
      verify_aud: true
    }).first
    
    # Find the user
    user = User.find_by(id: payload["sub"])
    
    # Check if the user exists and the token is not revoked
    if user && !JwtDenylist.jwt_revoked?(payload, user)
      success!(user)
    else
      fail!("Invalid or revoked token")
    end
  rescue JWT::DecodeError => e
    fail!(e.message)
  end
end
