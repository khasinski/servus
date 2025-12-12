# frozen_string_literal: true

module Servus
  module Guards
    # Guard that ensures a numeric value is positive (greater than zero).
    #
    # @example Basic usage
    #   class TransferService < Servus::Base
    #     def call
    #       ensure_positive!(amount: amount)
    #       # ...
    #     end
    #   end
    #
    # @example With custom parameter name
    #   ensure_positive!(balance: account.balance)
    class EnsurePositive < Servus::Guard
      severity :failure
      http_status 422
      error_code 'must_be_positive'

      message "%{key_name} must be positive (got %{value})" do
        key = kwargs.keys.first
        {
          key_name: key.to_s,
          value: kwargs[key]
        }
      end

      # Tests whether the value is positive.
      #
      # @param value [Numeric] the value to test (parameter name is flexible)
      # @return [Boolean] true if the value is greater than zero
      def test(**values)
        value = values.values.first
        value.is_a?(Numeric) && value > 0
      end
    end
  end
end
