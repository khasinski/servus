# @title Features / 6. Guards

# Guards

Guards are reusable validation rules that halt service execution when conditions aren't met. They provide a declarative way to enforce preconditions with rich, API-friendly error responses.

## Why Guards?

Instead of scattering validation logic throughout services:

```ruby
# Without guards - repetitive and verbose
def call
  return failure("User required", type: ValidationError) unless user
  return failure("User must be active", type: ValidationError) unless user.active?
  # ... business logic ...
end
```

Use guards for clean, declarative validation:

```ruby
# With guards - clear and reusable
def call
  enforce_presence!(user: user)
  enforce_truthy!(on: user, check: :active)
  # ... business logic ...
end
```

## Built-in Guards

Servus includes four guards by default:

### PresenceGuard

Validates that all values are present (not nil or empty):

```ruby
# Single value
enforce_presence!(user: user)

# Multiple values - all must be present
enforce_presence!(user: user, account: account, device: device)

# Works with strings, arrays, hashes
enforce_presence!(email: email)           # fails if nil or ""
enforce_presence!(items: cart.items)      # fails if nil or []
enforce_presence!(data: response.body)    # fails if nil or {}
```

Error: `"user must be present (got nil)"` or `"email must be present (got \"\")"`

### TruthyGuard

Validates that attribute(s) on an object are truthy:

```ruby
# Single attribute
enforce_truthy!(on: user, check: :active)

# Multiple attributes - all must be truthy
enforce_truthy!(on: user, check: [:active, :verified, :confirmed])

# Conditional check
if check_truthy?(on: subscription, check: :valid?)
  process_subscription
end
```

Error: `"User.active must be truthy (got false)"`

### FalseyGuard

Validates that attribute(s) on an object are falsey:

```ruby
# Single attribute - user must not be banned
enforce_falsey!(on: user, check: :banned)

# Multiple attributes - all must be falsey
enforce_falsey!(on: post, check: [:deleted, :hidden, :flagged])

# Conditional check
if check_falsey?(on: user, check: :suspended)
  allow_action
end
```

Error: `"User.banned must be falsey (got true)"`

### StateGuard

Validates that an attribute matches an expected value or one of several allowed values:

```ruby
# Single expected value
enforce_state!(on: order, check: :status, is: :pending)

# Multiple allowed values - any match passes
enforce_state!(on: account, check: :status, is: [:active, :trial])

# Conditional check
if check_state?(on: order, check: :status, is: :shipped)
  send_tracking_email
end
```

Errors:
- Single value: `"Order.status must be pending (got shipped)"`
- Multiple values: `"Account.status must be one of active, trial (got suspended)"`

## Guard Methods

Each guard defines two methods on `Servus::Guards`:

- **Bang method (`!`)** - Throws on failure, halts execution
- **Predicate method (`?`)** - Returns boolean, continues execution

```ruby
# Bang method - use for preconditions that must pass
enforce_presence!(user: user)  # throws :guard_failure if nil

# Predicate method - use for conditional logic
if check_truthy?(on: account, check: :premium)
  apply_premium_discount
else
  apply_standard_rate
end
```

## Creating Custom Guards

Define guards by inheriting from `Servus::Guard`:

```ruby
# app/guards/sufficient_balance_guard.rb
class SufficientBalanceGuard < Servus::Guard
  http_status 422
  error_code 'insufficient_balance'

  message 'Insufficient balance: need %<required>s, have %<available>s' do
    message_data
  end

  def test(account:, amount:)
    account.balance >= amount
  end

  private

  def message_data
    {
      required: kwargs[:amount],
      available: kwargs[:account].balance
    }
  end
end
```

This automatically defines `enforce_sufficient_balance!` and `check_sufficient_balance?` methods.

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

The message block has access to all kwargs passed to the guard via `kwargs`.

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
    enforce_state!(on: from_account, check: :status, is: :active)
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
error.message     # "Account.status must be active (got suspended)"
error.code        # "invalid_state"
error.http_status # 422
```

## Naming Convention

Guard class names are converted to method names by stripping the `Guard` suffix and converting to snake_case:

| Class Name | Bang Method | Predicate Method |
|------------|-------------|------------------|
| `SufficientBalanceGuard` | `enforce_sufficient_balance!` | `check_sufficient_balance?` |
| `ValidAmountGuard` | `enforce_valid_amount!` | `check_valid_amount?` |
| `AuthorizedGuard` | `enforce_authorized!` | `check_authorized?` |

The built-in guards follow this pattern: `TruthyGuard` -> `enforce_truthy!` / `check_truthy?`.

## Rails Auto-Loading

In Rails, guards in `app/guards/` are automatically loaded. Files must follow the `*_guard.rb` naming convention:

```
app/guards/
├── sufficient_balance_guard.rb
├── valid_amount_guard.rb
└── authorized_guard.rb
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
RSpec.describe Servus::Guards::TruthyGuard do
  let(:user_class) do
    Struct.new(:active, :verified, keyword_init: true) do
      def self.name
        'User'
      end
    end
  end

  describe '#test' do
    it 'passes when attribute is truthy' do
      user = user_class.new(active: true)
      guard = described_class.new(on: user, check: :active)
      expect(guard.test(on: user, check: :active)).to be true
    end

    it 'fails when attribute is falsey' do
      user = user_class.new(active: false)
      guard = described_class.new(on: user, check: :active)
      expect(guard.test(on: user, check: :active)).to be false
    end
  end

  describe '#error' do
    it 'returns GuardError with correct metadata' do
      user = user_class.new(active: false)
      guard = described_class.new(on: user, check: :active)
      error = guard.error

      expect(error.code).to eq('must_be_truthy')
      expect(error.message).to include('User', 'active', 'false')
      expect(error.http_status).to eq(422)
    end
  end
end
```

Test guards in service integration:

```ruby
RSpec.describe TransferService do
  it 'fails when account is not active' do
    result = described_class.call(
      from_account: suspended_account,
      to_account: recipient,
      amount: 100
    )

    expect(result).to be_failure
    expect(result.error.code).to eq('invalid_state')
  end
end
```