# well_formed-dry_types

[dry-types](https://dry-rb.org/gems/dry-types) coercion integration for [WellFormed](https://github.com/bmorrall/well_formed) form objects.

Declare typed attributes with `dry_attribute` and coercion runs automatically before validation — keeping your forms free of manual casting logic.

## Installation

```bash
bundle add well_formed-dry_types
```

## Usage

Require the gem in your application:

```ruby
require "well_formed-dry_types"
```

Include `WellFormed::DryTypes` in any form, then use `dry_attribute` in place of `attribute` for fields that need type coercion:

```ruby
module Types
  include Dry.Types()
end

class CreateOrderForm < WellFormed::ResourceForm
  include WellFormed::DryTypes

  resource_alias :order

  dry_attribute :quantity, Types::Params::Integer
  dry_attribute :amount,   Types::Params::Decimal
  dry_attribute :status,   Types::String.enum("pending", "confirmed")

  validates :quantity, presence: true, numericality: {greater_than: 0}
  validates :amount,   presence: true
  validates :status,   presence: true
end
```

Coercion runs before validation. If coercion fails, an error is added to the attribute and validation is skipped for that field:

```ruby
form = CreateOrderForm.new(order, current_user, {quantity: "abc", amount: "9.99", status: "pending"})
form.valid?
# => false
form.errors[:quantity]
# => ["must be Params::Integer"]  # dry-types error message
```

## Custom error messages

Pass `message:` to override the default dry-types error message.

#### I18n key

```ruby
dry_attribute :status, Types::String.enum("pending", "confirmed"), message: :inclusion
```

Passes the symbol to `errors.add`, which resolves it through your I18n translations.

#### Literal string

```ruby
dry_attribute :amount, Types::Params::Decimal, message: "must be a number"
```

#### Default (no message option)

```ruby
dry_attribute :quantity, Types::Params::Integer
```

Falls back to the error message from dry-types itself.

## Inheritance

`_dry_attributes` merges up the superclass chain, so subclass forms inherit parent coercions and can add their own:

```ruby
class BaseOrderForm < WellFormed::ResourceForm
  include WellFormed::DryTypes
  dry_attribute :amount, Types::Params::Decimal
end

class CreateOrderForm < BaseOrderForm
  dry_attribute :quantity, Types::Params::Integer
  # inherits :amount coercion from BaseOrderForm
end
```

## API

| Class macro | Description |
|---|---|
| `dry_attribute(name, type, message: nil)` | Declares a coerced attribute. Coercion runs before validation via a `before_validate` callback. |

## How it works

When `WellFormed::DryTypes` is included, a `before_validate` callback (`_coerce_dry_attributes`) is registered. Before each validation run, every `dry_attribute` is coerced in declaration order. On `Dry::Types::CoercionError`, an error is added and the raw value is left in place. Subsequent validators can still run against the failing attribute (e.g. a `presence` check on a nil optional).

## License

MIT
