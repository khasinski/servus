# frozen_string_literal: true

module Servus
  # Module providing guard functionality to Servus services.
  #
  # Guard methods are defined directly on this module when guard classes
  # inherit from Servus::Guard. The inherited hook triggers method definition,
  # so no registry or method_missing is needed.
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
  module Guards
    # Guard methods are defined dynamically via Servus::Guard.inherited
    # when guard classes are loaded. Each guard class defines:
    #   - ensure_<name>!  (throws :guard_failure on failure)
    #   - ensure_<name>?  (returns boolean)

    class << self
      # Loads default guards if configured.
      #
      # Called after Guards module is defined to load built-in guards
      # when Servus.config.include_default_guards is true.
      #
      # @return [void]
      # @api private
      def load_defaults
        return unless Servus.config.include_default_guards

        require_relative 'guards/ensure_present'
        require_relative 'guards/ensure_positive'
      end
    end
  end
end

# Load default guards based on configuration
Servus::Guards.load_defaults
