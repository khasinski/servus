# @title Features / 6. Guards

# Guards

Guards are reusable validation rules that halt service execution when conditions aren't met. They provide a declarative way to enforce preconditions with rich, API-friendly error responses.

## Why Guards?

Instead of scattering validation logic throughout services:

```ruby
# Without guards - repetitive and verbose
def call
  return failure("User required", type: ValidationError) unless user
  return failure("Amount must be positive", type: ValidationError) unless amount.positive?
  # ... business logic ...
end
```

Use guards for clean, declarative validation:

```ruby
# With guards - clear and reusable
def call
  enforce_present!(user: user)
  enforce_positive!(amount: amount)
  # ... business logic ...
end
```

## Built-in Guards

Servus includes two guards by default:

### PresenceGuard

Validates that all values are present (not nil or empty):

```ruby
# Single value
enforce_present!(user: user)

# Multiple values - all must be present
enforce_present!(user: user, account: account, device: device)

# Works with strings, arrays, hashes
enforce_present!(email: email)           # fails if nil or ""
enforce_present!(items: cart.items)      # fails if nil or []
enforce_present!(data: response.body)    # fails if nil or {}
```

### PositiveGuard

Validates that a numeric value is greater than zero:

```ruby
enforce_positive!(amount: amount)
enforce_positive!(balance: account.balance)
enforce_positive!(quantity: line_item.quantity)
```

## Guard Methods

Each guard defines two methods on `Servus::Guards`:

- **Bang method (`!`)** - Throws on failure, halts execution
- **Predicate method (`?`)** - Returns boolean, continues execution

```ruby
# Bang method - use for preconditions that must pass
enforce_present!(user: user)  # throws :guard_failure if nil

# Predicate method - use for conditional logic
if enforce_positive?(amount: amount)
  process_payment(amount)
else
  apply_refund(amount.abs)
end
```

## Creating Custom Guards

Define guards by inheriting from `Servus::Guard`:

```ruby
# app/guards/enforce_sufficient_balance_guard.rb
class EnsureSufficientBalanceGuard < Servus::Guard
  http_status 422
  error_code 'insufficient_balance'

  message 'Insufficient balance: need %<required>s, have %<available>s' do
    {
      required: amount,
      available: account.balance
    }
  end

  def test(account:, amount:)
    account.balance >= amount
  end
end
```

This automatically defines `enforce_sufficient_balance!` and `enforce_sufficient_balance?` methods.

### Guard DSL

**`http_status`** - HTTP status code for API responses (default: 422)

```ruby
http_status 422  # Unprocessable Entity
http_status 403  # Forbidden
http_status 400  # Bad Request
```

**`error_code`** - Machine-readable error code for API clients

```ruby
error_code 'insufficient_balance'
error_code 'daily_limit_exceeded'
error_code 'account_locked'
```

**`message`** - Human-readable error message with optional interpolation

```ruby
# Static message
message 'Amount must be positive'

# With interpolation (uses Ruby's % formatting)
message 'Balance: %<current>s, Required: %<required>s' do
  { current: account.balance, required: amount }
end
```

The message block has access to all kwargs passed to the guard.

**`test`** - The validation logic (must return boolean)

```ruby
def test(account:, amount:)
  account.balance >= amount
end
```

## Message Templates

Guards support multiple message template formats:

### String with Interpolation

```ruby
message 'Insufficient balance: need %<required>s, have %<available>s' do
  { required: amount, available: account.balance }
end
```

### I18n Symbol

```ruby
message :insufficient_balance
# Looks up: I18n.t('guards.insufficient_balance')
# Falls back to: "Insufficient balance" (humanized)
```

### Inline Translations

```ruby
message(
  en: 'Insufficient balance',
  es: 'Saldo insuficiente',
  fr: 'Solde insuffisant'
)
```

### Dynamic Proc

```ruby
message -> { "Limit exceeded for #{limit_type} transfers" }
```

## Error Handling

When a bang guard fails, it throws `:guard_failure` with a `GuardError`. Services automatically catch this and return a failure response:

```ruby
class TransferService < Servus::Base
  def call
    enforce_sufficient_balance!(account: from_account, amount: amount)
    # If guard fails, execution stops here
    # Service returns: Response(success: false, error: GuardError)

    transfer_funds
    success(transfer: transfer)
  end
end
```

The `GuardError` includes all metadata:

```ruby
error = guard.error
error.message     # "Insufficient balance: need 150, have 100"
error.code        # "insufficient_balance"
error.http_status # 422
```

## Naming Convention

Guard class names are converted to method names:

| Class Name | Bang Method | Predicate Method |
|------------|-------------|------------------|
| `EnsureSufficientBalanceGuard` | `enforce_sufficient_balance!` | `enforce_sufficient_balance?` |
| `EnsureValidAmountGuard` | `enforce_valid_amount!` | `enforce_valid_amount?` |
| `EnsureAuthorizedGuard` | `enforce_authorized!` | `enforce_authorized?` |

The `Ensure` prefix is normalized to avoid `enforce_enforce_...` patterns.

## Rails Auto-Loading

In Rails, guards in `app/guards/` are automatically loaded. Files must follow the `*_guard.rb` naming convention:

```
app/guards/
├── enforce_sufficient_balance_guard.rb
├── enforce_valid_amount_guard.rb
└── enforce_authorized_guard.rb
```

## Configuration

Disable built-in guards if you want to define your own (you can have both):

```ruby
Servus.configure do |config|
  config.include_default_guards = false        # Default: true
  config.guards_dir             = 'app/guards' # Default: 'app/guards'
end
```

## Testing Guards

Test guards in isolation:

```ruby
RSpec.describe EnsureSufficientBalanceGuard do
  let(:account) { double(balance: 100) }

  describe '#test' do
    it 'passes when balance is sufficient' do
      guard = described_class.new(account: account, amount: 50)
      expect(guard.test(account: account, amount: 50)).to be true
    end

    it 'fails when balance is insufficient' do
      guard = described_class.new(account: account, amount: 150)
      expect(guard.test(account: account, amount: 150)).to be false
    end
  end

  describe '#error' do
    it 'returns GuardError with correct metadata' do
      guard = described_class.new(account: account, amount: 150)
      error = guard.error

      expect(error.code).to eq('insufficient_balance')
      expect(error.message).to include('150', '100')
      expect(error.http_status).to eq(422)
    end
  end
end
```

Test guards in service integration:

```ruby
RSpec.describe TransferService do
  it 'fails when balance is insufficient' do
    result = described_class.call(
      from_account: account_with_low_balance,
      to_account: recipient,
      amount: 1000
    )

    expect(result).to be_failure
    expect(result.error.code).to eq('insufficient_balance')
  end
end
```