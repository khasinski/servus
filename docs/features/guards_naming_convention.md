# Servus Guards: Final Naming Convention

## The Pattern

### Class Naming: `<Condition>Guard`

**Rule:** Guard class names should describe **what is being checked**, NOT the action.

- ✅ **DO** use nouns, adjectives, or states
- ❌ **DON'T** use action verbs like "Enforce", "Check", "Verify", "Require", "Assert"

### Generated Methods

The framework automatically generates two methods:

1. **Bang method:** `enforce_<condition>!` - Enforces the rule or throws
2. **Predicate method:** `check_<condition>?` - Checks if the rule is met

---

## ✅ Good Examples

### Example 1: Balance Check

```ruby
# ✅ GOOD - Describes the condition
class SufficientBalanceGuard < Servus::Guard
  message 'Insufficient balance: need %<required>s, have %<available>s' do
    { required: amount, available: account.balance }
  end

  def test(account:, amount:)
    account.balance >= amount
  end
end

# Generates:
enforce_sufficient_balance!(account: account, amount: amount)
check_sufficient_balance?(account: account, amount: amount)
```

**Why it's good:** "SufficientBalance" describes the state/condition being checked.

---

### Example 2: Presence Check

```ruby
# ✅ GOOD - Describes the condition
class PresenceGuard < Servus::Guard
  message '%<keys>s must be present' do
    { keys: kwargs.keys.join(', ') }
  end

  def test(**values)
    values.values.all?(&:present?)
  end
end

# Generates:
enforce_presence!(user: user, account: account)
check_presence?(user: user, account: account)
```

**Alternative naming:**
```ruby
# Also good
class NotNilGuard < Servus::Guard
  # ...
end

# Generates:
enforce_not_nil!(user: user)
check_not_nil?(user: user)
```

---

### Example 3: Authorization

```ruby
# ✅ GOOD - Describes the requirement
class AdminRoleGuard < Servus::Guard
  message 'User must have admin role' do
    {}
  end

  def test(user:)
    user.admin?
  end
end

# Generates:
enforce_admin_role!(user: user)
check_admin_role?(user: user)
```

---

### Example 4: Product Feature

```ruby
# ✅ GOOD - Describes the enabled state
class EnabledProductGuard < Servus::Guard
  message 'Product %<product_name>s is not enabled' do
    { product_name: product.name }
  end

  def test(product:)
    product.enabled?
  end
end

# Generates:
enforce_enabled_product!(product: product)
check_enabled_product?(product: product)
```

---

### Example 5: Age Requirement

```ruby
# ✅ GOOD - Describes the requirement
class MinimumAgeGuard < Servus::Guard
  message 'Must be at least %<minimum>s years old' do
    { minimum: 18 }
  end

  def test(date_of_birth:)
    age = ((Time.zone.now - date_of_birth.to_time) / 1.year.seconds).floor
    age >= 18
  end
end

# Generates:
enforce_minimum_age!(date_of_birth: user.date_of_birth)
check_minimum_age?(date_of_birth: user.date_of_birth)
```

---

### Example 6: Rate Limiting

```ruby
# ✅ GOOD - Describes the limit state
class DailyLimitRemainingGuard < Servus::Guard
  message 'Daily limit exceeded: %<used>s/%<limit>s' do
    {
      used: user.daily_api_calls,
      limit: user.daily_api_limit
    }
  end

  def test(user:)
    user.daily_api_calls < user.daily_api_limit
  end
end

# Generates:
enforce_daily_limit_remaining!(user: user)
check_daily_limit_remaining?(user: user)
```

---

### Example 7: Ownership

```ruby
# ✅ GOOD - Describes the relationship
class OwnershipGuard < Servus::Guard
  message 'User does not own this resource' do
    {}
  end

  def test(user:, resource:)
    resource.user_id == user.id
  end
end

# Generates:
enforce_ownership!(user: user, resource: account)
check_ownership?(user: user, resource: account)
```

---

## ❌ Bad Examples (DON'T DO THIS)

### Example 1: Using "Enforce" in Class Name

```ruby
# ❌ BAD - Uses action verb
class EnforceSufficientBalanceGuard < Servus::Guard
  # ...
end

# Generates (redundant!):
enforce_enforce_sufficient_balance!(...)  # ❌ Redundant!
check_enforce_sufficient_balance?(...)    # ❌ Doesn't make sense!
```

**Why it's bad:** The action verb "Enforce" is already added by the framework.

---

### Example 2: Using "Check" in Class Name

```ruby
# ❌ BAD - Uses action verb
class CheckPresenceGuard < Servus::Guard
  # ...
end

# Generates (redundant!):
enforce_check_presence!(...)  # ❌ Weird!
check_check_presence?(...)    # ❌ Redundant!
```

**Why it's bad:** The action verb "Check" is already added by the framework.

---

### Example 3: Using "Require" in Class Name

```ruby
# ❌ BAD - Uses action verb
class RequireAdminRoleGuard < Servus::Guard
  # ...
end

# Generates (awkward!):
enforce_require_admin_role!(...)  # ❌ Double action verbs!
check_require_admin_role?(...)    # ❌ Confusing!
```

**Why it's bad:** "Require" is an action verb that conflicts with the framework's verbs.

---

### Example 4: Using "Verify" in Class Name

```ruby
# ❌ BAD - Uses action verb
class VerifyOwnershipGuard < Servus::Guard
  # ...
end

# Generates (awkward!):
enforce_verify_ownership!(...)  # ❌ Double action verbs!
check_verify_ownership?(...)    # ❌ Confusing!
```

**Why it's bad:** "Verify" is an action verb that conflicts with the framework.

---

### Example 5: Using "Validate" in Class Name

```ruby
# ❌ BAD - Uses action verb
class ValidateEmailGuard < Servus::Guard
  # ...
end

# Generates (awkward!):
enforce_validate_email!(...)  # ❌ Double action verbs!
check_validate_email?(...)    # ❌ Confusing!
```

**Why it's bad:** "Validate" is an action verb.

---

## 📝 Naming Guidelines

### DO: Use Descriptive Conditions

**Pattern:** `<Adjective><Noun>Guard` or `<Noun>Guard`

Examples:
- `SufficientBalanceGuard` - adjective + noun
- `PresenceGuard` - noun
- `AdminRoleGuard` - noun
- `EnabledProductGuard` - adjective + noun
- `MinimumAgeGuard` - adjective + noun
- `ActiveDeviceGuard` - adjective + noun
- `ValidEmailGuard` - adjective + noun
- `PositiveAmountGuard` - adjective + noun
- `UniqueEmailGuard` - adjective + noun

### DON'T: Use Action Verbs

**Avoid these prefixes:**
- ❌ `Enforce...Guard`
- ❌ `Check...Guard`
- ❌ `Verify...Guard`
- ❌ `Require...Guard`
- ❌ `Assert...Guard`
- ❌ `Validate...Guard`
- ❌ `Ensure...Guard`
- ❌ `Demand...Guard`
- ❌ `Test...Guard`

**Why:** The framework automatically adds `enforce_` and `check_` prefixes to the generated methods.

---

## 🎯 Naming Tips

### Tip 1: Think About the Condition, Not the Action

**Ask yourself:** "What state or condition am I checking?"

- ✅ "Is the balance sufficient?" → `SufficientBalanceGuard`
- ✅ "Is the user present?" → `PresenceGuard`
- ✅ "Does the user have admin role?" → `AdminRoleGuard`
- ✅ "Is the product enabled?" → `EnabledProductGuard`

**Don't ask:** "What action am I taking?"

- ❌ "I'm enforcing balance" → `EnforceBalanceGuard` (wrong!)
- ❌ "I'm checking presence" → `CheckPresenceGuard` (wrong!)

---

### Tip 2: Use Adjectives for States

When checking if something is in a certain state, use an adjective:

- `ActiveDeviceGuard` - device is active
- `ValidEmailGuard` - email is valid
- `PositiveAmountGuard` - amount is positive
- `UniqueEmailGuard` - email is unique
- `EnabledProductGuard` - product is enabled

---

### Tip 3: Use Nouns for Existence/Presence

When checking if something exists or is present:

- `PresenceGuard` - checks presence
- `OwnershipGuard` - checks ownership
- `AdminRoleGuard` - checks for admin role
- `PermissionGuard` - checks for permission

---

### Tip 4: Describe Requirements Positively

Prefer positive descriptions over negative:

- ✅ `SufficientBalanceGuard` (positive)
- ⚠️ `InsufficientBalanceGuard` (negative - works but less clear)

- ✅ `ActiveDeviceGuard` (positive)
- ⚠️ `InactiveDeviceGuard` (negative)

- ✅ `ValidEmailGuard` (positive)
- ⚠️ `InvalidEmailGuard` (negative)

**Exception:** Sometimes negative is clearer:

- `NotNilGuard` - clear and concise
- `NotEmptyGuard` - clear what it checks

---

## 📚 Complete Examples Library

### Simple Validations

```ruby
class PresenceGuard < Servus::Guard
  # enforce_presence! / check_presence?
end

class NotNilGuard < Servus::Guard
  # enforce_not_nil! / check_not_nil?
end

class PositiveAmountGuard < Servus::Guard
  # enforce_positive_amount! / check_positive_amount?
end

class ValidEmailGuard < Servus::Guard
  # enforce_valid_email! / check_valid_email?
end

class UniqueEmailGuard < Servus::Guard
  # enforce_unique_email! / check_unique_email?
end
```

### Business Rules

```ruby
class SufficientBalanceGuard < Servus::Guard
  # enforce_sufficient_balance! / check_sufficient_balance?
end

class DailyLimitRemainingGuard < Servus::Guard
  # enforce_daily_limit_remaining! / check_daily_limit_remaining?
end

class MinimumPurchaseAmountGuard < Servus::Guard
  # enforce_minimum_purchase_amount! / check_minimum_purchase_amount?
end

class WithinTransferLimitGuard < Servus::Guard
  # enforce_within_transfer_limit! / check_within_transfer_limit?
end
```

### Authorization

```ruby
class AdminRoleGuard < Servus::Guard
  # enforce_admin_role! / check_admin_role?
end

class OwnershipGuard < Servus::Guard
  # enforce_ownership! / check_ownership?
end

class PermissionGuard < Servus::Guard
  # enforce_permission! / check_permission?
end

class ActiveMembershipGuard < Servus::Guard
  # enforce_active_membership! / check_active_membership?
end
```

### Resource States

```ruby
class ActiveDeviceGuard < Servus::Guard
  # enforce_active_device! / check_active_device?
end

class EnabledProductGuard < Servus::Guard
  # enforce_enabled_product! / check_enabled_product?
end

class AvailableInventoryGuard < Servus::Guard
  # enforce_available_inventory! / check_available_inventory?
end

class OpenAccountGuard < Servus::Guard
  # enforce_open_account! / check_open_account?
end
```

### Compliance

```ruby
class MinimumAgeGuard < Servus::Guard
  # enforce_minimum_age! / check_minimum_age?
end

class CompletedKYCGuard < Servus::Guard
  # enforce_completed_kyc! / check_completed_kyc?
end

class AcceptedTermsGuard < Servus::Guard
  # enforce_accepted_terms! / check_accepted_terms?
end

class VerifiedEmailGuard < Servus::Guard
  # enforce_verified_email! / check_verified_email?
end
```

---

## 🔄 Migration Guide

If you have existing guards with action verbs, here's how to rename them:

### Before (with action verbs)
```ruby
class EnforceSufficientBalanceGuard < Servus::Guard
  # ...
end

# Usage:
enforce_enforce_sufficient_balance!(...)  # Redundant!
```

### After (condition only)
```ruby
class SufficientBalanceGuard < Servus::Guard
  # ...
end

# Usage:
enforce_sufficient_balance!(...)  # Clean!
check_sufficient_balance?(...)    # Clear!
```

### Rename Mapping

| Old Name (❌) | New Name (✅) |
|--------------|--------------|
| `EnforceSufficientBalanceGuard` | `SufficientBalanceGuard` |
| `RequirePresenceGuard` | `PresenceGuard` |
| `CheckAdminRoleGuard` | `AdminRoleGuard` |
| `VerifyOwnershipGuard` | `OwnershipGuard` |
| `AssertPositiveGuard` | `PositiveAmountGuard` |
| `EnsureValidEmailGuard` | `ValidEmailGuard` |
| `DemandActiveDeviceGuard` | `ActiveDeviceGuard` |

---

## ✅ Summary

**The Golden Rule:**

> Guard class names describe **WHAT** is being checked, not **HOW** it's being checked.

**Pattern:**
```ruby
class <Condition>Guard < Servus::Guard
  # Describes the condition/state/requirement
end

# Framework generates:
enforce_<condition>!  # Action verb added by framework
check_<condition>?    # Action verb added by framework
```

**Examples:**
- `SufficientBalanceGuard` → `enforce_sufficient_balance!` / `check_sufficient_balance?`
- `PresenceGuard` → `enforce_presence!` / `check_presence?`
- `AdminRoleGuard` → `enforce_admin_role!` / `check_admin_role?`
- `EnabledProductGuard` → `enforce_enabled_product!` / `check_enabled_product?`

**Remember:** Let the framework add the action verbs. Your job is to describe the condition! 🎯
