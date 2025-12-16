## Servus Gem


Servus is a gem for creating and managing service objects. It includes:

- A base class for service objects
- Generators for core service objects and specs
- Support for schema validation
- Support for error handling
- Support for logging
- Event-driven architecture with EventHandlers

👉🏽 [View the docs](https://zarpay.github.io/servus/)

## Generators

Service objects can be easily created using the `rails g servus:service namespace/service_name [*params]` command. For sake of consistency, use this command when generating new service objects.

### Generate Service

```bash
$ rails g servus:service namespace/do_something_helpful user
=>    create  app/services/namespace/do_something_helpful/service.rb
      create  spec/services/namespace/do_something_helpful/service_spec.rb
      create  app/schemas/services/namespace/do_something_helpful/result.json
      create  app/schemas/services/namespace/do_something_helpful/arguments.json
```

### Destroy Service

```bash
$ rails d servus:service namespace/do_something_helpful
=>    remove  app/services/namespace/do_something_helpful/service.rb
      remove  spec/services/namespace/do_something_helpful/service_spec.rb
      remove  app/schemas/services/namespace/do_something_helpful/result.json
      remove  app/schemas/services/namespace/do_something_helpful/arguments.json
```

## Arguments

Service objects should use keyword arguments rather than positional arguments for improved clarity and more meaningful error messages.

```ruby
# Good ✅
class Services::ProcessPayment::Service < Servus::Base
  def initialize(user:, amount:, payment_method:)
    @user = user
    @amount = amount
    @payment_method = payment_method
  end
end

# Bad ❌
class Services::ProcessPayment::Service < Servus::Base
  def initialize(user, amount, payment_method)
    @user = user
    @amount = amount
    @payment_method = payment_method
  end
end
```

## Directory Structure

Each service belongs in its own namespace with this structure:

- `app/services/service_name/service.rb` - Main class/entry point
- `app/services/service_name/support/` - Service-specific supporting classes

Supporting classes should never be used outside their parent service.

```
app/services/
├── process_payment/
│   ├── service.rb
│   └── support/
│       ├── payment_validator.rb
│       └── receipt_generator.rb
├── generate_report/
│   ├── service.rb
│   └── support/
│       ├── report_formatter.rb
│       └── data_collector.rb
```

## **Methods**

Every service object must implement:

- An `initialize` method that sets instance variables
- A parameter-less `call` instance method that executes the service logic

```ruby
class Services::GenerateReport::Service < Servus::Base
  def initialize(user:, report_type:, date_range:)
    @user = user
    @report_type = report_type
    @date_range = date_range
  end

  def call
    data = collect_data
    if data.empty?
      return failure("No data available for the selected date range")
    end

    formatted_report = format_report(data)
    success(formatted_report)
  end

  private

  def collect_data
		# Implementation details...
	end

  def format_report(data)
		# Implementation details...
	end
end

```

## **Asynchronous Execution**

You can asynchronously execute any service class that inherits from `Servus::Base` using `.call_async`. This uses `ActiveJob` under the hood and supports standard job options (`wait`, `queue`, `priority`, etc.). Only available in environments where `ActiveJob` is loaded (e.g., Rails apps)

```ruby
# Good ✅
Services::NotifyUser::Service.call_async(
  user_id: current_user.id,
  wait: 5.minutes,
  queue: :low_priority,
  job_options: { tags: ['notifications'] }
)

# Bad ❌
Services::NotifyUser::Support::MessageBuilder.call_async(
  # Invalid: support classes don't inherit from Servus::Base
)
```

## **Inheritance**

- Every main service class (`service.rb`) must inherit from `Servus::Base`
- Supporting classes should NOT inherit from `Servus::Base`

```ruby
# Good ✅
class Services::NotifyUser::Service < Servus::Base
	# Service implementation
end

class Services::NotifyUser::Support::MessageBuilder
	# Support class implementation (does NOT inherit from BaseService)
end

# Bad ❌
class Services::NotifyUser::Support::MessageBuilder < Servus::Base
	# Incorrect: support classes should not inherit from Base class
end
```

## **Call Chain**

Always use the class method `call` instead of manual instantiation. The `call` method:

1. Initializes an instance of the service using provided keyword arguments
2. Calls the instance-level `call` method
3. Handles schema validation of inputs and outputs
4. Handles logging of inputs and results
5. Automatically benchmarks execution time for performance monitoring

```ruby
# Good ✅
result = Services::ProcessPayment::Service.call(
  amount: 50,
  user_id: 123,
  payment_method: "credit_card"
)

# Bad ❌ - bypasses logging and other class-level functionality
service = Services::ProcessPayment::Service.new(
  amount: 50,
  user_id: 123,
  payment_method: "credit_card"
)
result = service.call

```

When services call other services, always use the class-level `call` method:

```ruby
def process_order
# Good ✅
  payment_result = Services::ProcessPayment::Service.call(
    amount: @order.total,
    payment_method: @payment_details
  )

# Bad ❌
  payment_service = Services::ProcessPayment::Service.new(
    amount: @order.total,
    payment_method: @payment_details
  )
  payment_result = payment_service.call
end

```

## **Responses**

The `Servus::Base` provides standardized response methods:

- `success(data)` - Returns success with data as a single argument
- `failure(message, **options)` - Logs error and returns failure response
- `error!(message)` - Logs error and raises exception

```ruby
def call
	# Return failure with message
	return failure("Order is not in a pending state") unless @order.pending?

    # Do something important

	# Process and return success with single data object
    success({
        order_id: @order.id,
        status: "processed",
        timestamp: Time.now
    })
end
```

All responses are `Servus::Support::Response` objects with a `success?` boolean attribute and either `data` (for success) or `error` (for error) attributes.

### Service Error Returns and Handling

By default, the `failure(...)` method creates an instance of `ServiceError` and adds it to the response type's `error` attribute. Standard and custom error types should inherit from the `ServiceError` class and optionally implement a custom `api_error` method. This enables developers to choose between using an API-specific error or generic error message in the calling context.

```ruby
# Called from within a Service Object
class SomeServiceObject::Service < Servus::Base
	def call
		# Return default ServiceError with custom message
		failure("That didn't work for some reason")
		#=> Response(false, nil, Servus::Support::Errors::ServiceError("That didn't work for some reason"))
		#
		# OR
		#
		# Specify ServiceError type with custom message
		failure("Custom message", type: Servus::Support::Errors::NotFoundError)
		#=> Response(false, nil, Servus::Support::Errors::NotFoundError("Custom message"))
		#
		# OR
		#
		# Specify ServiceError type with default message
		failure(type: Servus::Support::Errors::NotFoundError)
		#=> Response(false, nil, Servus::Support::Errors::NotFoundError("Not found"))
		#
		# OR
		#
		# Accept all defaults
		failure
		#=> Response(false, nil, Servus::Support::Errors::ServiceError("An error occurred"))
	end
end

# Error handling in parent context
class SomeController < AppController
	def controller_action
	  result = SomeServiceObject::Service.call(arg: 1)

	  return if result.success?

	  # If you just want the error message
	  bad_request(result.error.message)

	  # If you want the API error
	  service_object_error(result.error.api_error)
	end
end
```

### `rescue_from` for service errors

Services can configure default error handling using the `rescue_from` method.

```ruby
class SomeServiceObject::Service < Servus::Base
  class SomethingBroke < StandardError; end
  class SomethingGlitched < StandardError; end

  # Rescue from standard errors and use custom error
  rescue_from
    SomethingBroke,
    SomethingGlitched,
    use: Servus::Support::Errors::ServiceUnavailableError # this is optional

  def call
    do_something
  end

  private

  def do_something
    make_and_api_call
    rescue Net::HTTPError => e
      raise SomethingGlitched, "Whoaaaa, something went wrong! #{e.message}"
    end
  end
end
```

```sh
result = SomeServiceObject::Service.call
# Failure response
result.error.class
=> Servus::Support::Errors::ServiceUnavailableError
result.error.message
=> "[SomeServiceObject::Service::SomethingGlitched]: Whoaaaa, something went wrong! Net::HTTPError (503)"
result.error.api_error
=> { code: :service_unavailable, message: "[SomeServiceObject::Service::SomethingGlitched]: Whoaaaa, something went wrong! Net::HTTPError (503)" }
```

The `rescue_from` method will rescue from the specified errors and use the specified error type to create a failure response object with
the custom error. It helps eliminate the need to manually rescue many errors and create failure responses within the call method of
a service object.

You can also provide a block for custom error handling:

```ruby
class SomeServiceObject::Service < Servus::Base
  # Custom error handling with a block
  rescue_from ActiveRecord::RecordInvalid do |exception|
    failure("Validation failed: #{exception.message}", type: ValidationError)
  end

  rescue_from Net::HTTPError do |exception|
    # Can even return success to recover from errors
    success(recovered: true, error_message: exception.message)
  end

  def call
    # Service logic
  end
end
```

The block receives the exception and has access to `success` and `failure` methods for creating the response.

## **Guards**

Guards are reusable validation rules that halt service execution when conditions aren't met. They provide declarative precondition checking with rich error responses.

### Built-in Guards

```ruby
def call
  # Validate values are present (not nil or empty)
  enforce_presence!(user: user, account: account)

  # Validate object attributes are truthy
  enforce_truthy!(on: user, check: :active)
  enforce_truthy!(on: user, check: [:active, :verified])  # all must be truthy

  # Validate object attributes are falsey
  enforce_falsey!(on: user, check: :banned)
  enforce_falsey!(on: post, check: [:deleted, :hidden])  # all must be falsey

  # Validate attribute matches expected value(s)
  enforce_state!(on: order, check: :status, is: :pending)
  enforce_state!(on: account, check: :status, is: [:active, :trial])  # any match passes

  # ... business logic ...
  success(result)
end
```

### Predicate Methods

Each guard has a predicate version for conditional logic:

```ruby
if check_truthy?(on: user, check: :premium)
  apply_premium_discount
else
  apply_standard_rate
end
```

### Custom Guards

Create custom guards in `app/guards/`:

```bash
$ rails g servus:guard open_account
=>    create  app/guards/open_account_guard.rb
      create  spec/guards/open_account_guard_spec.rb
```

```ruby
# app/guards/open_account_guard.rb
class OpenAccountGuard < Servus::Guard
  http_status 422
  error_code 'open_account_required'

  message 'Invalid account: %<name> does not have an open account' do
    message_data
  end

  def test(user:)
    user.account.present? && user.account.status_open?
  end

  private

  def message_data
    {
      name: kwargs[:user].name
    }
  end
end

# Usage in services:
# enforce_open_account!(user: user_record)  # throws on failure
# check_open_account?(user: user_record)    # returns boolean
```

### Guard Error Responses

When a guard fails, the service returns a failure response with structured error data:

```ruby
result = TransferService.call(from_account: account, amount: 1000)
result.success?          # => false
result.error.message     # => "Invalid account: Bob Jones does not have an open account"
result.error.code        # => "open_account_required"
result.error.http_status # => 422
```

## Controller Helpers

Service objects can be called from controllers using the `run_service` and `render_service_error` helpers.

### run_service

`run_service` calls the service object with the provided parameters and sets an instance variable `@result` to the
result of the service object. If the result is not successful, it automatically calls `render_service_error` with
the error. This provides consistent error handling across controllers.

```ruby
class SomeController < AppController
  # Before
  def controller_action
    result = Services::SomeServiceObject::Service.call(my_params)
    return if result.success?
    render_service_error(result.error)
  end

  # After
  def controller_action_refactored
    run_service Services::SomeServiceObject::Service, my_params
  end
end
```

### render_service_error

`render_service_error` renders a service error as JSON. It takes an error object (not a hash) and uses
`error.http_status` for the response status and `error.api_error` for the response body.

```ruby
# Behind the scenes, render_service_error calls the following:
#
#  render json: { error: error.api_error }, status: error.http_status
#
# Which produces a response like:
#  { "error": { "code": "not_found", "message": "User not found" } }
#  with HTTP status 404

class SomeController < AppController
  def controller_action
    result = Services::SomeServiceObject::Service.call(my_params)
    return if result.success?

    render_service_error(result.error)
  end
end
```

Override `render_service_error` in your controller to customize error response format:

```ruby
class ApplicationController < ActionController::Base
  def render_service_error(error)
    render json: {
      error: {
        type: error.api_error[:code],
        details: error.message,
        timestamp: Time.current
      }
    }, status: error.http_status
  end
end
```

## **Schema Validation**

Service objects support two methods for schema validation: JSON Schema files and inline schema declarations.

### 1. File-based Schema Validation

Every service can have corresponding schema files in the centralized schema directory:

- `app/schemas/services/service_name/arguments.json` - Validates input arguments
- `app/schemas/services/service_name/result.json` - Validates success response data

Example `arguments.json`:

```json
{
  "type": "object",
  "required": ["user_id", "amount", "payment_method"],
  "properties": {
    "user_id": { "type": "integer" },
    "amount": {
      "type": "integer",
      "minimum": 1
    },
    "payment_method": {
      "type": "string",
      "enum": ["credit_card", "paypal", "bank_transfer"]
    },
    "currency": {
      "type": "string",
      "default": "USD"
    }
  },
  "additionalProperties": false
}

```

Example `result.json`:

```json
{
  "type": "object",
  "required": ["transaction_id", "status"],
  "properties": {
    "transaction_id": { "type": "string" },
    "status": {
      "type": "string",
      "enum": ["approved", "pending", "declined"]
    },
    "receipt_url": { "type": "string" }
  }
}

```

### 2. Inline Schema Validation

Schemas can be declared directly within the service class using the `schema` DSL method:

```ruby
class Services::ProcessPayment::Service < Servus::Base
  schema(
    arguments: {
      type: "object",
      required: ["user_id", "amount", "payment_method"],
      properties: {
        user_id: { type: "integer" },
        amount: {
          type: "integer",
          minimum: 1
        },
        payment_method: {
          type: "string",
          enum: ["credit_card", "paypal", "bank_transfer"]
        },
        currency: {
          type: "string",
          default: "USD"
        }
      },
      additionalProperties: false
    },
    result: {
      type: "object",
      required: ["transaction_id", "status"],
      properties: {
        transaction_id: { type: "string" },
        status: {
          type: "string",
          enum: ["approved", "pending", "declined"]
        },
        receipt_url: { type: "string" }
      }
    }
  )

  def initialize(user_id:, amount:, payment_method:, currency: 'USD')
    @user_id = user_id
    @amount = amount
    @payment_method = payment_method
    @currency = currency
  end

  def call
    # Service logic...
    success({
      transaction_id: "txn_1",
      status: "approved"
    })
  end
end
```

---

These schemas use JSON Schema format to enforce type safety and input/output contracts. For detailed information on authoring JSON Schema files, refer to the official specification at: https://json-schema.org/specification.html

### Schema Resolution

The validation system follows this precedence:

1. Schemas defined via `schema` DSL method (recommended)
2. Inline schema constants (`ARGUMENTS_SCHEMA` or `RESULT_SCHEMA`) - legacy support
3. JSON files in schema_root directory - legacy support
4. Returns nil if no schema is found (validation is opt-in)

### Schema Caching

Both file-based and inline schemas are automatically cached:

- First validation request loads and caches the schema
- Subsequent validations use the cached version
- Cache can be cleared using `Servus::Support::Validator.clear_cache!`

## **Logging**

Servus automatically logs service execution details, making it easy to track and debug service calls.

### Automatic Logging

Every service call automatically logs:

- **Service invocation** with input arguments
- **Success results** with execution duration
- **Failure results** with error details and duration
- **Validation errors** for schema violations
- **Uncaught exceptions** with error messages

### Logger Configuration

The logger automatically adapts to your environment:

- **Rails applications**: Uses `Rails.logger`
- **Non-Rails applications**: Uses stdout logger

### Log Output Examples

```ruby
# Success
INFO -- : Calling Services::ProcessPayment::Service with args: {:user_id=>123, :amount=>50}
INFO -- : Services::ProcessPayment::Service succeeded in 0.245s

# Failure
INFO -- : Calling Services::ProcessPayment::Service with args: {:user_id=>123, :amount=>50}
WARN -- : Services::ProcessPayment::Service failed in 0.156s with error: Insufficient funds

# Validation Error
ERROR -- : Services::ProcessPayment::Service validation error: The property '#/amount' value -10 was less than minimum value 1

# Exception
ERROR -- : Services::ProcessPayment::Service uncaught exception: NoMethodError - undefined method 'charge' for nil:NilClass
```

All logging happens transparently when using the class-level `.call` method. This is one of the reasons why direct instantiation (bypassing `.call`) is discouraged.

## **Configuration**

Servus can be configured to customize behavior for your application needs.

### Schema Root Directory

By default, Servus looks for schema files in `app/schemas/services/`. You can customize this location:

```ruby
# config/initializers/servus.rb
Servus.configure do |config|
  config.schema_root = Rails.root.join('lib/schemas')
end
```

### Default Behavior

Without explicit configuration:

- **Rails applications**: Schema root defaults to `Rails.root/app/schemas/services`
- **Non-Rails applications**: Schema root defaults to `./app/schemas/services` relative to the gem installation

The configuration is accessed through the singleton `Servus.config` instance and can be modified using `Servus.configure`.

## **Event Bus**

Servus includes an event-driven architecture for decoupling service logic from side effects. Services emit events, and EventHandlers subscribe to them and invoke downstream services.

### Emitting Events from Services

Services can declare events that are emitted on success or failure:

```ruby
class CreateUser::Service < Servus::Base
  emits :user_created, on: :success
  emits :user_creation_failed, on: :failure

  def initialize(email:, name:)
    @email = email
    @name = name
  end

  def call
    user = User.create!(email: @email, name: @name)
    success(user: user)
  rescue ActiveRecord::RecordInvalid => e
    failure(e.message)
  end
end
```

Custom payloads can be provided via blocks or method references:

```ruby
emits :user_created, on: :success do |result|
  { user_id: result.data[:user].id, email: result.data[:user].email }
end
```

### Event Handlers

EventHandlers subscribe to events and invoke services in response. They live in `app/events/`:

```ruby
# app/events/user_created_handler.rb
class UserCreatedHandler < Servus::EventHandler
  handles :user_created

  invoke SendWelcomeEmail::Service, async: true do |payload|
    { user_id: payload[:user_id], email: payload[:email] }
  end

  invoke TrackAnalytics::Service, async: true do |payload|
    { event: 'user_created', user_id: payload[:user_id] }
  end
end
```

### Generate Event Handler

```bash
$ rails g servus:event_handler user_created
=>    create  app/events/user_created_handler.rb
      create  spec/events/user_created_handler_spec.rb
```

### Invocation Options

```ruby
# Synchronous (default)
invoke NotifyAdmin::Service do |payload|
  { message: "New user: #{payload[:email]}" }
end

# Async via ActiveJob
invoke SendEmail::Service, async: true do |payload|
  { user_id: payload[:user_id] }
end

# Async with specific queue
invoke SendEmail::Service, async: true, queue: :mailers do |payload|
  { user_id: payload[:user_id] }
end

# Conditional invocation
invoke GrantRewards::Service, if: ->(p) { p[:premium] } do |payload|
  { user_id: payload[:user_id] }
end
```

### Emitting Events Directly

EventHandlers provide an `emit` class method for emitting events from controllers, jobs, or other code:

```ruby
class UsersController < ApplicationController
  def create
    user = User.create!(user_params)
    UserCreatedHandler.emit({ user_id: user.id, email: user.email })
    redirect_to user
  end
end
```

### Payload Schema Validation

Define JSON schemas to validate event payloads:

```ruby
class UserCreatedHandler < Servus::EventHandler
  handles :user_created

  schema payload: {
    type: 'object',
    required: ['user_id', 'email'],
    properties: {
      user_id: { type: 'integer' },
      email: { type: 'string', format: 'email' }
    }
  }

  invoke SendWelcomeEmail::Service, async: true do |payload|
    { user_id: payload[:user_id], email: payload[:email] }
  end
end
```

### Testing Events

Servus provides RSpec matchers for testing events:

```ruby
# Test that a service emits an event
it 'emits user_created event' do
  expect {
    CreateUser::Service.call(email: 'test@example.com', name: 'Test')
  }.to emit_event(:user_created)
end

# Test payload content
it 'emits event with expected payload' do
  expect {
    CreateUser::Service.call(email: 'test@example.com', name: 'Test')
  }.to emit_event(:user_created).with(hash_including(email: 'test@example.com'))
end

# Test handler invokes service
it 'invokes SendWelcomeEmail' do
  expect {
    UserCreatedHandler.handle(payload)
  }.to call_service(SendWelcomeEmail::Service).with(user_id: 123)
end
```
