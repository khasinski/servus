# frozen_string_literal: true

module Servus
  module Guards
    # Guard that ensures all provided values are present (not nil or empty).
    #
    # This is a flexible guard that accepts any number of keyword arguments
    # and validates that all values are present.
    #
    # @example Basic usage
    #   class MyService < Servus::Base
    #     def call
    #       enforce_presence!(user: user, account: account)
    #       # ...
    #     end
    #   end
    #
    # @example Single value
    #   enforce_presence!(email: email)
    #
    # @example Multiple values
    #   enforce_presence!(user: user, account: account, device: device)
    #
    # @example Conditional check
    #   if check_presence?(user: user)
    #     # user is present
    #   end
    class PresenceGuard < Servus::Guard
      http_status 422
      error_code 'must_be_present'

      message '%<key_names>s must be present' do
        {
          key_names: kwargs.keys.map(&:to_s).join(', ')
        }
      end

      # Tests whether all provided values are present.
      #
      # A value is considered present if it is not nil and not empty
      # (for values that respond to empty?).
      #
      # @param values [Hash] keyword arguments to validate
      # @return [Boolean] true if all values are present
      def test(**values)
        values.values.all? do |value|
          if value.respond_to?(:empty?)
            !value.nil? && !value.empty?
          else
            !value.nil?
          end
        end
      end
    end
  end
end
