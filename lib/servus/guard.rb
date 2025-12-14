# frozen_string_literal: true

module Servus
  # Base class for guards that encapsulate validation logic with rich error responses.
  #
  # Guard classes define reusable validation rules with declarative metadata and
  # localized error messages. They provide a clean, performant alternative to
  # scattering validation logic throughout services.
  #
  # @example Basic guard
  #   class EnsureSufficientBalance < Servus::Guard
  #     http_status 422
  #     error_code 'insufficient_balance'
  #
  #     message "Insufficient balance: need %{required}, have %{available}" do
  #       {
  #         required: amount,
  #         available: account.balance
  #       }
  #     end
  #
  #     def test(account:, amount:)
  #       account.balance >= amount
  #     end
  #   end
  #
  # @example Using a guard in a service
  #   class TransferService < Servus::Base
  #     def call
  #       ensure_sufficient_balance!(account: from_account, amount: amount)
  #       # ... perform transfer ...
  #       success(result)
  #     end
  #   end
  #
  # @see Servus::Guards
  # @see Servus::Base
  class Guard
    class << self
      # Executes a guard and throws :guard_failure with the guard's error if validation fails.
      #
      # This is the bang (!) execution method that halts execution on failure.
      # The caller is responsible for catching the thrown error and handling it.
      #
      # @param guard_class [Class] the guard class to execute
      # @param kwargs [Hash] keyword arguments for the guard
      # @return [void] returns nil if guard passes
      # @throw [:guard_failure, GuardError] if guard fails
      #
      # @example
      #   Servus::Guard.execute!(EnsurePositive, amount: 100)  # passes, returns nil
      #   Servus::Guard.execute!(EnsurePositive, amount: -10) # throws :guard_failure
      def execute!(guard_class, **)
        guard = guard_class.new(**)
        return if guard.test(**)

        throw(:guard_failure, guard.error)
      end

      # Executes a guard and returns boolean result without throwing.
      #
      # This is the predicate (?) execution method for conditional checks.
      #
      # @param guard_class [Class] the guard class to execute
      # @param kwargs [Hash] keyword arguments for the guard
      # @return [Boolean] true if guard passes, false otherwise
      #
      # @example
      #   Servus::Guard.execute?(EnsurePositive, amount: 100) # => true
      #   Servus::Guard.execute?(EnsurePositive, amount: -10) # => false
      def execute?(guard_class, **)
        guard_class.new(**).test(**)
      end

      # Declares the HTTP status code for API responses.
      #
      # @param status [Integer] the HTTP status code
      # @return [void]
      #
      # @example
      #   class MyGuard < Servus::Guard
      #     http_status 422
      #   end
      def http_status(status)
        @http_status_code = status
      end

      # Returns the HTTP status code.
      #
      # @return [Integer, nil] the HTTP status code or nil if not set
      attr_reader :http_status_code

      # Declares the error code for API responses.
      #
      # @param code [String] the error code
      # @return [void]
      #
      # @example
      #   class MyGuard < Servus::Guard
      #     error_code 'insufficient_balance'
      #   end
      def error_code(code)
        @error_code_value = code
      end

      # Returns the error code.
      #
      # @return [String, nil] the error code or nil if not set
      attr_reader :error_code_value

      # Declares the message template and data block.
      #
      # The template can be a String (static or with %{} interpolation),
      # a Symbol (I18n key), a Proc (dynamic), or a Hash (inline translations).
      #
      # The block provides data for message interpolation and is evaluated
      # in the guard instance's context.
      #
      # @param template [String, Symbol, Proc, Hash] the message template
      # @yield block that returns a Hash of interpolation data
      # @return [void]
      #
      # @example With string template
      #   message "Balance must be at least %{minimum}" do
      #     { minimum: 100 }
      #   end
      #
      # @example With I18n key
      #   message :insufficient_balance do
      #     { required: amount, available: account.balance }
      #   end
      def message(template, &block)
        @message_template = template
        @message_block    = block if block_given?
      end

      # Returns the message template.
      #
      # @return [String, Symbol, Proc, Hash, nil] the message template
      attr_reader :message_template

      # Returns the message data block.
      #
      # @return [Proc, nil] the message data block
      attr_reader :message_block

      # Hook called when a class inherits from Guard.
      #
      # Automatically defines guard methods on the Servus::Guards module.
      #
      # @param subclass [Class] the inheriting class
      # @return [void]
      # @api private
      def inherited(subclass)
        super
        register_guard_methods(subclass)
      end

      # Defines bang and predicate methods on Servus::Guards for the guard class.
      #
      # @param guard_class [Class] the guard class to register
      # @return [void]
      # @api private
      def register_guard_methods(guard_class)
        return unless guard_class.name

        method_name = derive_method_name(guard_class)

        # Define bang method (throws on failure)
        Servus::Guards.define_method("#{method_name}!") do |**kwargs|
          Servus::Guard.execute!(guard_class, **kwargs)
        end

        # Define predicate method (returns boolean)
        Servus::Guards.define_method("#{method_name}?") do |**kwargs|
          Servus::Guard.execute?(guard_class, **kwargs)
        end
      end

      # Converts a guard class name to a method name.
      #
      # @param guard_class [Class] the guard class
      # @return [String] the method name (without ! or ?)
      # @api private
      def derive_method_name(guard_class)
        class_name = guard_class.name.split('::').last
        "ensure_#{class_name.gsub(/^Ensure/, '')
          .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
          .gsub(/([a-z\d])([A-Z])/, '\1_\2')
          .downcase}"
      end
    end

    attr_reader :kwargs

    # Initializes a new guard instance with the provided arguments.
    #
    # @param kwargs [Hash] keyword arguments for the guard
    def initialize(**kwargs)
      @kwargs = kwargs
    end

    # Tests whether the guard passes.
    #
    # Subclasses must implement this method with explicit keyword arguments
    # that define the guard's contract.
    #
    # @return [Boolean] true if the guard passes, false otherwise
    # @raise [NotImplementedError] if not implemented by subclass
    #
    # @example
    #   def test(account:, amount:)
    #     account.balance >= amount
    #   end
    def test
      raise NotImplementedError, "#{self.class} must implement #test"
    end

    # Returns the formatted error message.
    #
    # Resolves the template (handling String, Symbol, Proc, Hash types),
    # evaluates the message data block, and interpolates the data into the template.
    #
    # @return [String] the formatted error message
    def message
      template = resolve_template
      data = instance_exec(&self.class.message_block) if self.class.message_block
      data ||= {}

      template % data
    end

    # Returns a GuardError instance configured with this guard's metadata.
    #
    # Called when a guard fails to create the error that gets thrown.
    # The caller decides how to handle the error (e.g., wrap in a failure response).
    #
    # @return [Servus::Support::Errors::GuardError] the error instance
    def error
      Servus::Support::Errors::GuardError.new(
        message,
        code: self.class.error_code_value || 'validation_failed',
        http_status: self.class.http_status_code || 422
      )
    end

    # Provides convenience access to kwargs as methods.
    #
    # This allows the message data block to access parameters directly
    # (e.g., `amount` instead of `kwargs[:amount]`).
    #
    # @param method_name [Symbol] the method name
    # @param args [Array] method arguments
    # @param block [Proc] method block
    # @return [Object] the value from kwargs
    # @raise [NoMethodError] if the method is not found
    # @api private
    def method_missing(method_name, *args, &)
      kwargs[method_name] || super
    end

    # Checks if the guard responds to a method.
    #
    # @param method_name [Symbol] the method name
    # @param include_private [Boolean] whether to include private methods
    # @return [Boolean] true if the method exists or is in kwargs
    # @api private
    def respond_to_missing?(method_name, include_private = false)
      kwargs.key?(method_name) || super
    end

    private

    # Resolves the message template to a string.
    #
    # Handles Symbol (I18n), Proc (dynamic), Hash (inline translations),
    # and String (static) template types.
    #
    # @return [String] the resolved template string
    # @api private
    def resolve_template
      template = self.class.message_template

      case template
      when Symbol
        # I18n lookup with fallback
        i18n_key = template.to_s.include?('.') ? template : "guards.#{template}"
        if defined?(I18n)
          I18n.t(i18n_key, default: template.to_s.tr('_', ' ').capitalize)
        else
          template.to_s.tr('_', ' ').capitalize
        end
      when Proc
        # Dynamic template (evaluated at runtime)
        instance_exec(&template)
      when Hash
        # Inline translations
        locale = defined?(I18n) ? I18n.locale : :en
        template[locale] || template[:en] || template.values.first
      else
        # Static string
        template.to_s
      end
    end
  end
end
