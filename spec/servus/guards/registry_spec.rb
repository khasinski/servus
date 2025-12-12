# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Servus::Guards::Registry do
  after do
    described_class.clear
  end

  describe '.register' do
    it 'registers a guard class with snake_case method name' do
      guard_class = Class.new(Servus::Guard)
      stub_const('EnsureSufficientBalance', guard_class)

      described_class.register(guard_class)

      expect(described_class.get(:ensure_sufficient_balance!)).to eq(guard_class)
    end

    it 'handles guards with namespace' do
      guard_class = Class.new(Servus::Guard)
      stub_const('Transfers::Guards::EnsureValidCurrency', guard_class)

      described_class.register(guard_class)

      expect(described_class.get(:ensure_valid_currency!)).to eq(guard_class)
    end

    it 'handles guards without Ensure prefix' do
      guard_class = Class.new(Servus::Guard)
      stub_const('CustomGuard', guard_class)

      described_class.register(guard_class)

      # Should still work, just without the Ensure prefix removal
      expect(described_class.get(:ensure_custom_guard!)).to eq(guard_class)
    end

    it 'handles acronyms correctly' do
      guard_class = Class.new(Servus::Guard)
      stub_const('EnsureAPIKeyValid', guard_class)

      described_class.register(guard_class)

      expect(described_class.get(:ensure_api_key_valid!)).to eq(guard_class)
    end

    it 'handles single-word guards' do
      guard_class = Class.new(Servus::Guard)
      stub_const('EnsurePresent', guard_class)

      described_class.register(guard_class)

      expect(described_class.get(:ensure_present!)).to eq(guard_class)
    end
  end

  describe '.get' do
    it 'retrieves a registered guard by symbol' do
      guard_class = Class.new(Servus::Guard)
      stub_const('EnsureSufficientBalance', guard_class)
      described_class.register(guard_class)

      expect(described_class.get(:ensure_sufficient_balance!)).to eq(guard_class)
    end

    it 'retrieves a registered guard by string' do
      guard_class = Class.new(Servus::Guard)
      stub_const('EnsureSufficientBalance', guard_class)
      described_class.register(guard_class)

      expect(described_class.get('ensure_sufficient_balance!')).to eq(guard_class)
    end

    it 'returns nil for unregistered guard' do
      expect(described_class.get(:ensure_non_existent!)).to be_nil
    end
  end

  describe '.all' do
    it 'returns all registered guards' do
      guard1 = Class.new(Servus::Guard)
      guard2 = Class.new(Servus::Guard)
      stub_const('EnsurePresent', guard1)
      stub_const('EnsureSufficientBalance', guard2)

      described_class.register(guard1)
      described_class.register(guard2)

      all_guards = described_class.all

      expect(all_guards.keys).to include(:ensure_present!, :ensure_sufficient_balance!)
      expect(all_guards.values).to include(guard1, guard2)
    end

    it 'returns a copy to prevent external modification' do
      guard_class = Class.new(Servus::Guard)
      stub_const('EnsurePresent', guard_class)
      described_class.register(guard_class)

      all_guards = described_class.all
      all_guards.clear

      expect(described_class.all).not_to be_empty
    end
  end

  describe '.clear' do
    it 'removes all registered guards' do
      guard_class = Class.new(Servus::Guard)
      stub_const('EnsurePresent', guard_class)
      described_class.register(guard_class)

      expect(described_class.all).not_to be_empty

      described_class.clear

      expect(described_class.all).to be_empty
    end
  end

  describe 'automatic registration via inheritance' do
    it 'automatically registers when a guard class is defined' do
      guard_class = Class.new(Servus::Guard)
      stub_const('EnsureDeviceAccessible', guard_class)

      # Registration happens in the inherited hook
      expect(described_class.get(:ensure_device_accessible!)).to eq(guard_class)
    end
  end
end
