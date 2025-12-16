# frozen_string_literal: true

module Servus
  module Support
    # Contains all error classes used by Servus services.
    #
    # All error classes inherit from {ServiceError} and provide:
    # - {ServiceError#http_status} for the HTTP response status
    # - {ServiceError#api_error} for the JSON response body
    #
    # @see ServiceError
    module Errors
      # Base error class for all Servus service errors.
      #
      # Subclasses define their HTTP status via {#http_status} and their
      # API response format via {#api_error}.
      #
      # @example Creating a custom error type
      #   class InsufficientFundsError < Servus::Support::Errors::ServiceError
      #     DEFAULT_MESSAGE = 'Insufficient funds'
      #
      #     def http_status = :unprocessable_entity
      #
      #     def api_error
      #       { code: 'insufficient_funds', message: message }
      #     end
      #   end
      #
      # @example Using with failure method
      #   def call
      #     return failure("User not found", type: NotFoundError)
      #   end
      class ServiceError < StandardError
        attr_reader :message

        DEFAULT_MESSAGE = 'An error occurred'

        # Creates a new service error instance.
        #
        # @param message [String, nil] custom error message (uses DEFAULT_MESSAGE if nil)
        def initialize(message = nil)
          @message = message || self.class::DEFAULT_MESSAGE
          super("#{self.class}: #{@message}")
        end

        # Returns the HTTP status code for this error.
        #
        # @return [Symbol] Rails-compatible status symbol
        def http_status = :bad_request

        # Returns an API-friendly error response.
        #
        # @return [Hash] hash with :code and :message keys
        def api_error = { code: http_status, message: message }
      end

      # 400 Bad Request - malformed or invalid request data.
      class BadRequestError < ServiceError
        DEFAULT_MESSAGE = 'Bad request'

        def http_status = :bad_request
        def api_error = { code: http_status, message: message }
      end

      # 401 Unauthorized - authentication credentials missing or invalid.
      class AuthenticationError < ServiceError
        DEFAULT_MESSAGE = 'Authentication failed'

        def http_status = :unauthorized
        def api_error = { code: http_status, message: message }
      end

      # 401 Unauthorized (alias for AuthenticationError).
      class UnauthorizedError < AuthenticationError
        DEFAULT_MESSAGE = 'Unauthorized'
      end

      # 403 Forbidden - authenticated but not authorized.
      class ForbiddenError < ServiceError
        DEFAULT_MESSAGE = 'Forbidden'

        def http_status = :forbidden
        def api_error = { code: http_status, message: message }
      end

      # 404 Not Found - requested resource does not exist.
      class NotFoundError < ServiceError
        DEFAULT_MESSAGE = 'Not found'

        def http_status = :not_found
        def api_error = { code: http_status, message: message }
      end

      # 422 Unprocessable Entity - semantic errors in request.
      class UnprocessableEntityError < ServiceError
        DEFAULT_MESSAGE = 'Unprocessable entity'

        def http_status = :unprocessable_entity
        def api_error = { code: http_status, message: message }
      end

      # 422 Validation Error - schema or business validation failed.
      class ValidationError < UnprocessableEntityError
        DEFAULT_MESSAGE = 'Validation failed'

        def api_error = { code: http_status, message: message }
      end

      # Guard validation failure with custom code.
      #
      # Guards define their own error code and HTTP status via the DSL.
      #
      # @example
      #   GuardError.new("Amount must be positive", code: 'invalid_amount', http_status: 422)
      class GuardError < ServiceError
        DEFAULT_MESSAGE = 'Guard validation failed'

        # @return [String] application-specific error code
        attr_reader :code

        # @return [Symbol, Integer] HTTP status code
        attr_reader :http_status

        # Creates a new guard error with metadata.
        #
        # @param message [String, nil] error message
        # @param code [String] error code for API responses (default: 'guard_failed')
        # @param http_status [Symbol, Integer] HTTP status (default: :unprocessable_entity)
        def initialize(message = nil, code: 'guard_failed', http_status: :unprocessable_entity)
          super(message)
          @code        = code
          @http_status = http_status
        end

        def api_error = { code: code, message: message }
      end

      # 500 Internal Server Error - unexpected server-side failure.
      class InternalServerError < ServiceError
        DEFAULT_MESSAGE = 'Internal server error'

        def http_status = :internal_server_error
        def api_error = { code: http_status, message: message }
      end

      # 503 Service Unavailable - dependency temporarily unavailable.
      class ServiceUnavailableError < ServiceError
        DEFAULT_MESSAGE = 'Service unavailable'

        def http_status = :service_unavailable
        def api_error = { code: http_status, message: message }
      end
    end
  end
end
