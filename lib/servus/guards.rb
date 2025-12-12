# frozen_string_literal: true

module Servus
  # Module providing guard functionality to Servus services.
  #
  # Guards are self-contained validation objects that encapsulate validation logic,
  # error messages, and metadata. When included in Servus::Base, this module provides
  # dynamic guard methods via method_missing.
  #
  # @example Using guards in a service
  #   class TransferService < Servus::Base
  #     def call
  #       ensure_present!(user: user, account: account)
  #       ensure_positive!(amount: amount)
  #       # ... perform transfer ...
  #       success(result)
  #     end
  #   end
  #
  # @see Servus::Guard
  # @see Servus::Guards::Registry
  module Guards
    # Provides guard methods to service instances via method_missing.
    #
    # When a method ending with `!` is called and matches a registered guard,
    # this method instantiates the guard, runs the test, and either:
    # - Continues execution if the guard passes
    # - Throws :guard_failure if the guard fails (caught by Servus::Base.call)
    #
    # @param method_name [Symbol] the method name
    # @param args [Array] positional arguments (not used)
    # @param kwargs [Hash] keyword arguments passed to the guard
    # @return [void]
    # @raise [NoMethodError] if the method is not a registered guard
    # @api private
    def method_missing(method_name, *args, **kwargs, &block)
      # Check if this is a guard method (ends with !)
      if method_name.to_s.end_with?('!')
        guard_class = Servus::Guards::Registry.get(method_name)

        if guard_class
          execute_guard(guard_class, **kwargs)
          return
        end
      end

      super
    end

    # Checks if the service responds to a guard method.
    #
    # @param method_name [Symbol] the method name
    # @param include_private [Boolean] whether to include private methods
    # @return [Boolean] true if the method is a registered guard
    # @api private
    def respond_to_missing?(method_name, include_private = false)
      if method_name.to_s.end_with?('!')
        Servus::Guards::Registry.get(method_name).present?
      else
        super
      end
    end

    private

    # Executes a guard and handles failure.
    #
    # If the guard test fails, stores the failure response and throws :guard_failure
    # to exit the service execution. The throw is caught by Servus::Base.call.
    #
    # @param guard_class [Class] the guard class to execute
    # @param kwargs [Hash] keyword arguments for the guard
    # @return [void]
    # @raise [ArgumentError] if guard test method signature doesn't match kwargs
    # @api private
    def execute_guard(guard_class, **kwargs)
      guard = guard_class.new(**kwargs)

      # Get the test method parameters to pass the right arguments
      test_method = guard.method(:test)
      test_params = test_method.parameters

      # If test method has explicit parameters, pass kwargs
      # If test method has **kwargs, pass all kwargs
      result = if test_params.any? { |type, _name| type == :keyrest }
                 guard.test(**kwargs)
               elsif test_params.any? { |type, _name| %i[key keyreq].include?(type) }
                 # Extract only the parameters the test method expects
                 expected_keys = test_params.select { |type, _name| %i[key keyreq].include?(type) }
                                            .map { |_type, name| name }
                 filtered_kwargs = kwargs.slice(*expected_keys)
                 guard.test(**filtered_kwargs)
               else
                 guard.test
               end

      return if result

      # Guard failed - store failure response and throw
      @failure_response = failure(guard.message, type: Servus::Support::Errors::ServiceError)
      throw(:guard_failure)
    end
  end
end
