# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Base, 'Guards Integration' do
  describe 'guard methods' do
    it 'provides guard methods via method_missing' do
      service_class = stub_const('GuardTestService1', Class.new(described_class) do
        def initialize(amount:)
          @amount = amount
        end

        def call
          ensure_positive!(amount: @amount)
          success({ result: 'processed' })
        end
      end)

      result = service_class.call(amount: 100)
      expect(result.success?).to be true
      expect(result.data).to eq({ result: 'processed' })
    end

    it 'stops execution when guard fails' do
      service_class = stub_const('GuardTestService2', Class.new(described_class) do
        def initialize(amount:)
          @amount = amount
        end

        def call
          ensure_positive!(amount: @amount)
          success({ result: 'processed' })
        end
      end)

      result = service_class.call(amount: -10)
      expect(result.success?).to be false
      expect(result.error.message).to include('must be positive')
    end

    it 'works with multiple guards' do
      service_class = stub_const('GuardTestService3', Class.new(described_class) do
        def initialize(user:, amount:)
          @user = user
          @amount = amount
        end

        def call
          ensure_present!(user: @user)
          ensure_positive!(amount: @amount)
          success({ result: 'processed' })
        end
      end)

      # All guards pass
      result = service_class.call(user: 'user123', amount: 100)
      expect(result.success?).to be true

      # First guard fails
      result = service_class.call(user: nil, amount: 100)
      expect(result.success?).to be false
      expect(result.error.message).to include('must be present')

      # Second guard fails
      result = service_class.call(user: 'user123', amount: -10)
      expect(result.success?).to be false
      expect(result.error.message).to include('must be positive')
    end

    it 'works in nested private methods' do
      service_class = stub_const('GuardTestService4', Class.new(described_class) do
        def initialize(user:, amount:)
          @user = user
          @amount = amount
        end

        def call
          validate_inputs
          success({ result: 'processed' })
        end

        private

        def validate_inputs
          ensure_present!(user: @user)
          ensure_positive!(amount: @amount)
        end
      end)

      # Guards pass
      result = service_class.call(user: 'user123', amount: 100)
      expect(result.success?).to be true

      # Guard fails in nested method
      result = service_class.call(user: nil, amount: 100)
      expect(result.success?).to be false
      expect(result.error.message).to include('must be present')
    end

    it 'works in deeply nested methods' do
      service_class = stub_const('GuardTestService5', Class.new(described_class) do
        def initialize(user:, amount:)
          @user = user
          @amount = amount
        end

        def call
          level1
          success({ result: 'processed' })
        end

        private

        def level1
          level2
        end

        def level2
          level3
        end

        def level3
          ensure_present!(user: @user)
          ensure_positive!(amount: @amount)
        end
      end)

      # Guards pass
      result = service_class.call(user: 'user123', amount: 100)
      expect(result.success?).to be true

      # Guard fails in deeply nested method
      result = service_class.call(user: 'user123', amount: -10)
      expect(result.success?).to be false
      expect(result.error.message).to include('must be positive')
    end

    it 'raises NoMethodError for non-existent guard' do
      service_class = stub_const('GuardTestService6', Class.new(described_class) do
        def call
          ensure_non_existent!(value: 123)
          success({})
        end
      end)

      expect { service_class.call }.to raise_error(NoMethodError, /ensure_non_existent!/)
    end
  end

  describe 'backward compatibility with raise' do
    it 'still works with traditional raise approach' do
      service_class = stub_const('GuardTestService7', Class.new(described_class) do
        def initialize(amount:)
          @amount = amount
        end

        def call
          raise Servus::Support::Errors::ServiceError, 'Amount must be positive' if @amount <= 0

          success({ result: 'processed' })
        end
      end)

      # Success case
      result = service_class.call(amount: 100)
      expect(result.success?).to be true

      # Failure case - raise still works
      expect { service_class.call(amount: -10) }
        .to raise_error(Servus::Support::Errors::ServiceError, 'Amount must be positive')
    end

    it 'can mix guards and raises' do
      service_class = stub_const('GuardTestService8', Class.new(described_class) do
        def initialize(user:, amount:)
          @user = user
          @amount = amount
        end

        def call
          # Use guard for validation
          ensure_present!(user: @user)

          # Use raise for exceptional error
          raise Servus::Support::Errors::ServiceError, 'System unavailable' if system_down?

          # Use guard for business rule
          ensure_positive!(amount: @amount)

          success({ result: 'processed' })
        end

        private

        def system_down?
          false
        end
      end)

      result = service_class.call(user: 'user123', amount: 100)
      expect(result.success?).to be true

      # Guard failure returns failure response
      result = service_class.call(user: nil, amount: 100)
      expect(result.success?).to be false
      expect(result.error.message).to include('must be present')
    end
  end

  describe 'respond_to?' do
    it 'returns true for registered guard methods' do
      service_class = stub_const('GuardTestService9', Class.new(described_class) do
        def call
          success({})
        end
      end)

      instance = service_class.new
      expect(instance.respond_to?(:ensure_present!)).to be true
      expect(instance.respond_to?(:ensure_positive!)).to be true
    end

    it 'returns false for non-existent guard methods' do
      service_class = stub_const('GuardTestService10', Class.new(described_class) do
        def call
          success({})
        end
      end)

      instance = service_class.new
      expect(instance.respond_to?(:ensure_non_existent!)).to be false
    end
  end

  describe 'error response structure' do
    it 'returns proper failure response with guard metadata' do
      service_class = stub_const('GuardTestService11', Class.new(described_class) do
        def initialize(amount:)
          @amount = amount
        end

        def call
          ensure_positive!(amount: @amount)
          success({ result: 'processed' })
        end
      end)

      result = service_class.call(amount: -10)

      expect(result.success?).to be false
      expect(result.error).to be_a(Servus::Support::Errors::ServiceError)
      expect(result.error.message).to eq('amount must be positive (got -10)')
    end
  end

  describe 'predicate guard methods' do
    it 'returns true when guard passes' do
      service_class = stub_const('GuardTestService12', Class.new(described_class) do
        def initialize(amount:)
          @amount = amount
        end

        def call
          if ensure_positive?(amount: @amount)
            success({ validated: true })
          else
            success({ validated: false })
          end
        end
      end)

      result = service_class.call(amount: 100)
      expect(result.success?).to be true
      expect(result.data[:validated]).to be true
    end

    it 'returns false when guard fails without throwing' do
      service_class = stub_const('GuardTestService13', Class.new(described_class) do
        def initialize(amount:)
          @amount = amount
        end

        def call
          if ensure_positive?(amount: @amount)
            success({ validated: true })
          else
            success({ validated: false })
          end
        end
      end)

      result = service_class.call(amount: -10)
      expect(result.success?).to be true
      expect(result.data[:validated]).to be false
    end
  end
end
