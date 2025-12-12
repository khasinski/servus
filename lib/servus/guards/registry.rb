# frozen_string_literal: true

module Servus
  module Guards
    # Registry for mapping guard method names to guard classes.
    #
    # When a guard class is defined, it automatically registers itself
    # with this registry. The registry converts the class name to a
    # snake_case method name with a `!` suffix.
    #
    # @example
    #   class EnsureSufficientBalance < Servus::Guard
    #     # Automatically registers as 'ensure_sufficient_balance!'
    #   end
    #
    #   Servus::Guards::Registry.get(:ensure_sufficient_balance!)
    #   # => EnsureSufficientBalance
    #
    # @api private
    module Registry
      @guards = {}

      class << self
        # Registers a guard class with the registry.
        #
        # Converts the class name to a method name following the pattern:
        # - EnsureSufficientBalance -> ensure_sufficient_balance!
        # - Transfers::Guards::EnsureValidCurrency -> ensure_valid_currency!
        #
        # @param guard_class [Class] the guard class to register
        # @return [void]
        def register(guard_class)
          # Extract the class name without module namespace
          class_name = guard_class.name.split('::').last
          return unless class_name

          # Convert EnsureSufficientBalance -> ensure_sufficient_balance!
          method_name = class_name
                        .gsub(/^Ensure/, '')                      # Remove Ensure prefix
                        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')    # Handle acronyms
                        .gsub(/([a-z\d])([A-Z])/, '\1_\2')        # CamelCase to snake_case
                        .downcase

          method_name = "ensure_#{method_name}!"

          @guards[method_name.to_sym] = guard_class
        end

        # Retrieves a guard class by method name.
        #
        # @param method_name [Symbol, String] the guard method name
        # @return [Class, nil] the guard class or nil if not found
        def get(method_name)
          @guards[method_name.to_sym]
        end

        # Returns all registered guards.
        #
        # @return [Hash<Symbol, Class>] map of method names to guard classes
        def all
          @guards.dup
        end

        # Clears all registered guards.
        #
        # Used primarily for testing to reset the registry state.
        #
        # @return [void]
        def clear
          @guards.clear
        end
      end
    end
  end
end
