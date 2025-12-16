# @title Integration / 1. Configuration

# Configuration

Servus works without configuration. Optional settings exist for customizing directories and event validation.

## Directory Configuration

Configure where Servus looks for schemas, services, event handlers, and guards:

```ruby
# config/initializers/servus.rb
Servus.configure do |config|
  # Default: 'app/schemas'
  config.schemas_dir = 'app/schemas'

  # Default: 'app/services'
  config.services_dir = 'app/services'

  # Default: 'app/events'
  config.events_dir = 'app/events'

  # Default: 'app/guards'
  config.guards_dir = 'app/guards'
end
```

These affect legacy file-based schemas, handler auto-loading, and guard auto-loading. Schemas defined via the `schema` DSL method do not use files.

## Schema Cache

Schemas are cached after first load for performance. Clear the cache during development when schemas change:

```ruby
Servus::Support::Validator.clear_cache!
```

In production, schemas are deployed with code - no need to clear cache.

## Log Level

Servus uses `Rails.logger` (or stdout in non-Rails apps). Control logging via Rails configuration:

```ruby
# config/environments/production.rb
config.log_level = :info  # Hides DEBUG argument logs
```

## ActiveJob Configuration

Async execution uses ActiveJob. Configure your adapter:

```ruby
# config/application.rb
config.active_job.queue_adapter = :sidekiq
config.active_job.default_queue_name = :default
```

Servus respects ActiveJob queue configuration - no Servus-specific setup needed.

## Guards Configuration

### Default Guards

Servus includes built-in guards (`PresenceGuard`, `TruthyGuard`, `FalseyGuard`, `StateGuard`) that are loaded by default. Disable them if you want to define your own:

```ruby
# config/initializers/servus.rb
Servus.configure do |config|
  # Default: true
  config.include_default_guards = false
end
```

### Guard Auto-Loading

In Rails, custom guards in `app/guards/` are automatically loaded. The Railtie eager-loads all `*_guard.rb` files from `config.guards_dir`:

```
app/guards/
├── sufficient_balance_guard.rb
├── valid_amount_guard.rb
└── authorized_guard.rb
```

Guards define methods on `Servus::Guards` when inherited from `Servus::Guard`. The `Guard` suffix is stripped from the method name:

```ruby
# app/guards/sufficient_balance_guard.rb
class SufficientBalanceGuard < Servus::Guard
  http_status 422
  error_code 'insufficient_balance'

  message 'Insufficient balance: need %<required>s, have %<available>s' do
    { required: amount, available: account.balance }
  end

  def test(account:, amount:)
    account.balance >= amount
  end
end

# Usage in services:
# enforce_sufficient_balance!(account: account, amount: 100)  # throws on failure
# check_sufficient_balance?(account: account, amount: 100)    # returns boolean
```

## Event Bus Configuration

### Strict Event Validation

Enable strict validation to catch handlers subscribing to events that aren't emitted by any service:

```ruby
# config/initializers/servus.rb
Servus.configure do |config|
  # Default: true
  config.strict_event_validation = true
end
```

When enabled, you can validate handlers at boot or in CI:

```ruby
# In a rake task or initializer
Servus::EventHandler.validate_all_handlers!
```

This raises `Servus::Events::OrphanedHandlerError` if any handler subscribes to a non-existent event.

### Handler Auto-Loading

In Rails, handlers in `app/events/` are automatically loaded. The Railtie:
- Clears the event bus on reload in development
- Eager-loads all `*_handler.rb` files from `config.events_dir`

```
app/events/
├── user_created_handler.rb
├── payment_processed_handler.rb
└── order_completed_handler.rb
```

### Event Instrumentation

Events are instrumented via ActiveSupport::Notifications with the prefix `servus.events.`:

```ruby
# Subscribe to all Servus events
ActiveSupport::Notifications.subscribe(/^servus\.events\./) do |name, *args|
  event_name = name.sub('servus.events.', '')
  Rails.logger.info "Event: #{event_name}"
end
```
