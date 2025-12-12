# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Guards::EnsurePositive do
  describe '#test' do
    context 'with positive values' do
      it 'returns true for positive integer' do
        guard = described_class.new(amount: 100)
        expect(guard.test(amount: 100)).to be true
      end

      it 'returns true for positive float' do
        guard = described_class.new(amount: 0.01)
        expect(guard.test(amount: 0.01)).to be true
      end

      it 'returns true for large positive number' do
        guard = described_class.new(amount: 1_000_000)
        expect(guard.test(amount: 1_000_000)).to be true
      end
    end

    context 'with zero' do
      it 'returns false for zero' do
        guard = described_class.new(amount: 0)
        expect(guard.test(amount: 0)).to be false
      end

      it 'returns false for zero float' do
        guard = described_class.new(amount: 0.0)
        expect(guard.test(amount: 0.0)).to be false
      end
    end

    context 'with negative values' do
      it 'returns false for negative integer' do
        guard = described_class.new(amount: -10)
        expect(guard.test(amount: -10)).to be false
      end

      it 'returns false for negative float' do
        guard = described_class.new(amount: -0.01)
        expect(guard.test(amount: -0.01)).to be false
      end
    end

    context 'with non-numeric values' do
      it 'returns false for string' do
        guard = described_class.new(amount: '100')
        expect(guard.test(amount: '100')).to be false
      end

      it 'returns false for nil' do
        guard = described_class.new(amount: nil)
        expect(guard.test(amount: nil)).to be false
      end

      it 'returns false for array' do
        guard = described_class.new(amount: [100])
        expect(guard.test(amount: [100])).to be false
      end
    end

    context 'with different parameter names' do
      it 'works with custom parameter name' do
        guard = described_class.new(balance: 100)
        expect(guard.test(balance: 100)).to be true
      end

      it 'works with another custom parameter name' do
        guard = described_class.new(price: 50.5)
        expect(guard.test(price: 50.5)).to be true
      end
    end
  end

  describe '#message' do
    it 'includes parameter name and value' do
      guard = described_class.new(amount: -10)
      expect(guard.message).to eq("amount must be positive (got -10)")
    end

    it 'works with custom parameter name' do
      guard = described_class.new(balance: 0)
      expect(guard.message).to eq("balance must be positive (got 0)")
    end

    it 'shows nil value' do
      guard = described_class.new(amount: nil)
      expect(guard.message).to eq("amount must be positive (got )")
    end
  end

  describe '#api_error' do
    it 'returns structured error response' do
      guard = described_class.new(amount: -10)
      error = guard.api_error

      expect(error).to eq({
                            code: 'must_be_positive',
                            message: 'amount must be positive (got -10)',
                            http_status: 422
                          })
    end
  end

  describe 'metadata' do
    it 'has correct severity' do
      expect(described_class.severity_level).to eq(:failure)
    end

    it 'has correct HTTP status' do
      expect(described_class.http_status_code).to eq(422)
    end

    it 'has correct error code' do
      expect(described_class.error_code_value).to eq('must_be_positive')
    end
  end

  describe 'registry integration' do
    it 'is registered as ensure_positive!' do
      expect(Servus::Guards::Registry.get(:ensure_positive!)).to eq(described_class)
    end
  end
end
