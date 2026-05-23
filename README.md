# WellFormed

WellFormed is a lightweight form object library for Rails. Inherit from `WellFormed::ResourceForm` for standard create/update flows, or `WellFormed::ActionForm` for custom actions that don't persist a resource — both accept a resource, a user, and a params hash, with full `ActiveModel::Model` and `ActiveModel::Attributes` support.

Form objects are compatible with `form_with` and Rails view helpers anywhere an ActiveRecord model would be accepted.

## Installation

TODO: Replace `UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG` with your gem name right after releasing it to RubyGems.org. Please do not do it earlier due to security reasons. Alternatively, replace this section with instructions to install your gem from git if you don't plan to release to RubyGems.org.

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG
```

## Usage

```ruby
class CreateArticleForm < WellFormed::ResourceForm
  resource_alias :article

  attribute :title, :string
  attribute :body, :string

  validates :title, presence: true
  validates :body,  presence: true
end
```

```ruby
# app/controllers/articles_controller.rb
def create
  @form = CreateArticleForm.new(Article.new, current_user, article_params)
  if (@article = @form.submit)
    redirect_to @article
  else
    render :new, status: :unprocessable_entity
  end
end
```

```ruby
# app/controllers/api/articles_controller.rb
def create
  @form = CreateArticleForm.new(Article.new, current_user, article_params)
  if @form.save
    render json: @form.article, status: :created
  else
    render json: {errors: @form.errors.messages}, status: :unprocessable_content
  end
end
```

```ruby
class PublishArticleForm < WellFormed::ActionForm
  resource_alias :article

  attribute :notify_subscribers, :boolean, default: false

  def perform
    article.publish!
    PublishMailer.notify(article).deliver_later if notify_subscribers
  end
end
```

```ruby
# app/controllers/articles_controller.rb
def publish
  @form = PublishArticleForm.new(@article, current_user, publish_params)
  if @form.submit
    redirect_to @article
  else
    render :edit, status: :unprocessable_entity
  end
end
```

### Constructor

```ruby
form = CreateArticleForm.new(article, current_user, { title: "Hello", body: "World" })
```

| Argument | Description |
|----------|-------------|
| `resource` | The ActiveRecord object (or any object) the form wraps |
| `user` | The user performing the action |
| `params` | A hash of form values to assign to declared attributes (optional, defaults to `{}`) |

```ruby
form.resource  # => article
form.user      # => current_user
form.title     # => "Hello"

form.valid?    # => true / false (ActiveModel validations)
form.errors    # => ActiveModel::Errors
```

### Overriding the constructor

Subclasses can define their own `initialize` — just call `super` to let the base set up `resource`, `user`, and attribute assignment. A common pattern is **nested resource creation**: the form accepts the parent as its first argument and builds the child record internally, keeping the controller clean:

```ruby
module Articles
  class CreatePostForm < WellFormed::ResourceForm
    resource_alias :post

    attribute :title, :string
    attribute :body,  :string

    validates :title, presence: true

    def initialize(article, user, params = {})
      super(article.posts.build, user, params)
    end
  end
end
```

```ruby
# Controller
def create
  @form = Articles::CreatePostForm.new(@article, current_user, post_params)
  if @form.save
    redirect_to @article
  else
    render :new, status: :unprocessable_entity
  end
end
```

`article.posts.build` scopes the new record to the parent so the association is set before `save` is called.

### Translations — `resource_alias`

Call `resource_alias` to declare what the wrapped resource represents. This does two things:

1. Adds a reader method on the form that aliases `resource` using the given name
2. Sets `model_name` so that ActiveModel error messages use the correct I18n translation keys

```ruby
class CreateArticleForm < WellFormed::ResourceForm
  resource_alias :article

  attribute :title, :string
  validates :title, presence: true
end

form = CreateArticleForm.new(article, current_user, {})
form.article          # => same as form.resource
form.errors.full_messages  # => ["Title can't be blank"] (keyed under "article.*")
```

`resource_alias` accepts a symbol, a snake_case or CamelCase string, or an ActiveModel class:

```ruby
resource_alias :article           # symbol
resource_alias "article_comment"  # snake_case string
resource_alias Article            # class — borrows Article.model_name directly
```

### Persistence — `save` and `submit`

The default `save` method:

1. Runs validations — returns `false` immediately if invalid
2. Assigns only form attributes that the resource has a corresponding setter for
3. Calls `save` on the resource and returns its result (`true` / `false`)

```ruby
form = CreateArticleForm.new(article, current_user, { title: "Hello", body: "World" })
form.save  # => true / false
```

`submit` is a convenience wrapper around `save` that returns the resource on success or `false` on failure, making controller code more concise:

```ruby
if (article = form.submit)
  render json: article.as_json, status: :created
else
  render json: { errors: form.errors.messages }, status: :unprocessable_entity
end
```

Use `save!` or `submit!` when you prefer raising over checking a return value — both raise `WellFormed::RecordInvalid` on failure:

```ruby
form.save!    # raises WellFormed::RecordInvalid if invalid or resource.save fails
form.submit!  # raises WellFormed::RecordInvalid if invalid or resource.save fails
              # (submit! also returns the resource on success)

rescue WellFormed::RecordInvalid => e
  e.record          # => the form object
  e.message         # => "Validation failed: Title can't be blank"
  e.record.errors   # => ActiveModel::Errors
end
```

For side effects around the save — sending emails, creating audit logs, etc. — use `before_save`, `after_save`, and `after_save_commit` callbacks. For forms that need fully custom persistence logic, consider `WellFormed::Struct` (plain Ruby object resources) or `WellFormed::ActionForm` (no resource persistence at all).

#### Unmatched attributes

Form attributes with no matching setter on the resource are silently skipped when `save` is called — they are filtered out before `assign_attributes` is called, so Rails never raises `ActiveModel::UnknownAttributeError`.

This is the normal case for virtual attributes like `agree_to_terms` or `current_password`, which exist on the form for validation or logic but have no corresponding column on the model — they are validated and accessible on the form as normal, without being assigned to the resource. Alternatively, declare the attribute on the form with `attr_writer` (or `attr_accessor`) instead of `attribute` — the value is still assigned from params, but won't be forwarded to the resource on save.

Use `unmatched_attributes` to opt in to a warning or error at the form level instead:

```ruby
class CreateArticleForm < WellFormed::ResourceForm
  unmatched_attributes :warn   # prints a warning to stderr
  # unmatched_attributes :raise  # raises WellFormed::UnmatchedAttributesError
  # unmatched_attributes :ignore # default — silent skip
end
```

`:warn` and `:raise` are useful during development to catch typos or attribute drift between the form and its resource.

#### Model validation errors — `merge_model_errors`

By default, `save` only runs form-level validations. If `resource.save` fails due to a model-level validation that the form does not replicate, `save` returns `false` with a generic `:base` error (`"could not be saved"`) so that `errors` is never silently empty.

When you want model errors surfaced on the form — for example in an API that uses `Halitosis::ErrorsSerializer` — declare `merge_model_errors` in the form class. The form will then copy `resource.errors` onto itself whenever `resource.save` returns `false`:

```ruby
class Api::CreateUserForm < WellFormed::ResourceForm
  resource_alias :user

  merge_model_errors  # copies resource.errors onto the form on save failure

  attribute :name,  :string
  attribute :email, :string

  validates :name,  presence: true
  validates :email, presence: true
  # No format validation here — the User model owns that rule
end
```

```ruby
# User model
class User < ApplicationRecord
  validates :email, format: { with: /\A[^@\s]+@[^@\s]+\z/, message: "is invalid" }
end
```

Submitting `email: "not-an-email"` passes form validation but fails at the model. With `merge_model_errors`, the error is copied back:

```ruby
form.save        # => false
form.errors[:email]  # => ["is invalid"]
```

This integrates cleanly with Halitosis error serialisation:

```ruby
render json: Halitosis::ErrorsSerializer.new(@form), status: :unprocessable_content
# { "errors": [{ "code": "email_invalid", "detail": "Email is invalid",
#                "source": { "pointer": "/user/email" } }] }
```

#### Callbacks — `before_validation` and `after_validation`

Use `before_validation` to normalise or coerce attribute values before the validation run, and `after_validation` to act on the errors that were just collected — or to transform attribute values before they are assigned to the resource.

```ruby
class CreateArticleForm < WellFormed::ResourceForm
  attribute :title, :string
  attribute :tag_list, :string

  validates :title, presence: true

  before_validation :normalise_title
  after_validation  :log_errors

  private

  def normalise_title
    self.title = title&.strip&.downcase
  end

  def log_errors
    Rails.logger.warn(errors.full_messages) if errors.any?
  end
end
```

Blocks are also accepted:

```ruby
before_validation { self.title = title&.strip }
```

To transform a form attribute before it reaches the resource, use `after_validation` — it runs after the validation run and before attributes are assigned:

```ruby
after_validation { self.title = title&.strip&.downcase }
```

#### Callbacks — `before_save` and `after_save`

Use `before_save` to run logic after attributes have been assigned to the resource but before it is saved. Use `after_save` to run logic once the resource has been saved.

```ruby
class CreateArticleForm < WellFormed::ResourceForm
  attribute :title, :string

  before_save :set_created_by
  after_save  :notify_subscribers

  private

  def set_created_by
    resource.created_by = user
  end

  def notify_subscribers
    NotificationMailer.new_article(resource).deliver_later
  end
end
```

Blocks are also accepted:

```ruby
before_save { resource.created_by = user }
```

A `before_save` callback can halt the save by calling `throw :abort`, in which case `save` returns `false` and `resource.save` is never called:

```ruby
before_save { throw :abort unless user.can_publish? }
```

#### Commit callbacks — `after_save_commit`

`after_save_commit` registers a callback that fires after all surrounding database transactions have committed — safe for side effects like sending emails or enqueuing background jobs that must not run if the transaction rolls back.

Internally, `after_save_commit` uses `ActiveRecord.after_all_transactions_commit` — so if `save` is called inside a larger controller-level transaction, the callbacks wait for the outermost transaction to commit before firing.

```ruby
class CreateArticleForm < WellFormed::ResourceForm
  after_save_commit :notify_subscribers

  private

  def notify_subscribers
    NotificationMailer.new_article(resource).deliver_later
  end
end
```

#### Transactions — `save_within_transaction`

Call `save_within_transaction` to wrap the entire save (including all callbacks) in a database transaction. If `resource.save` returns `false`, or any callback raises, the transaction is rolled back automatically:

```ruby
class CreateArticleForm < WellFormed::ResourceForm
  resource_alias :article

  attribute :title,  :string
  attribute :body,   :string

  validates :title, presence: true

  save_within_transaction

  after_save        :create_audit_log    # runs inside the transaction
  after_save_commit :notify_subscribers  # runs after the transaction commits

  private

  def create_audit_log
    AuditLog.create!(action: :created, record: article, user: user)
  end

  def notify_subscribers
    NotificationMailer.new_article(article).deliver_later
  end
end
```

If `AuditLog.create!` raises, the article save is rolled back with it. `after_save_commit` callbacks only fire once the transaction successfully commits.

## Action forms

For custom actions that don't map to a standard create/update — publishing, archiving, sending a notification — inherit from `WellFormed::ActionForm`. These are identical to regular forms except that attributes are not assigned to the resource, `save` is never called, and there is no default `save` implementation. You define `perform` instead.

```ruby
class PublishArticleForm < WellFormed::ActionForm
  resource_alias :article

  attribute :notify_subscribers, :boolean, default: false

  validates :article, presence: true

  def perform
    article.publish!
    PublishMailer.notify(article).deliver_later if notify_subscribers
  end
end
```

Call `submit` to run validations and then `perform`, or `submit!` to raise on failure:

```ruby
form = PublishArticleForm.new(article, current_user, { notify_subscribers: true })
form.submit   # => true if perform ran, false if invalid or halted by before_perform
              # if halted with no errors, a generic base error ("could not be performed") is added
form.submit!  # raises WellFormed::RecordInvalid if invalid or before_perform halts
```

### Callbacks — `before_perform` and `after_perform`

`before_perform` and `after_perform` work the same way as `before_save`/`after_save` in regular forms:

```ruby
class PublishArticleForm < WellFormed::ActionForm
  before_perform :check_permissions
  after_perform  :audit_log

  def perform
    article.publish!
  end

  def check_permissions
    throw :abort unless user.can_publish?(article)
  end

  def audit_log
    AuditLog.record(user, :published, article)
  end
end
```

Blocks are also accepted:

```ruby
before_perform { throw :abort unless user.can_publish?(article) }
```

## Nested attributes

Nested form objects are built in to `WellFormed::ResourceForm`, `WellFormed::ActionForm`, and `WellFormed::Struct`.

```ruby
class CreateOrderForm < WellFormed::ResourceForm
  resource_alias :order

  attribute :customer_name, :string
  validates :customer_name, presence: true

  nested_attributes_for :line_items do
    attribute :name,     :string
    attribute :quantity, :integer

    validates :name,     presence: true
    validates :quantity, numericality: { greater_than: 0 }
  end

  nested_attribute_for :billing_address do
    attribute :street,   :string
    attribute :city,     :string
    attribute :postcode, :string

    validates :street,   presence: true
    validates :city,     presence: true
    validates :postcode, presence: true
  end
end
```

### Macros

| Macro | Wraps |
|-------|-------|
| `nested_attributes_for :name` | A **collection** of nested forms (e.g. `has_many`) |
| `nested_attribute_for  :name` | A **single** nested form (e.g. `has_one` / `belongs_to`) |

Each macro accepts either an inline block (shown above) or an explicit form class:

```ruby
nested_attributes_for :line_items, LineItemForm
nested_attribute_for  :billing_address, BillingAddressForm
```

Passing both raises `ArgumentError`.

### Setters

Each macro defines two setters — both do the same thing and can be used interchangeably:

| Setter | Use case |
|--------|----------|
| `name_attributes=` | Rails `fields_for` / `simple_fields_for` (HTML form params with `_attributes` suffix) |
| `name=`            | API-style params without the suffix |

The underlying resource receives `name_attributes=` immediately when either setter is called, so `accepts_nested_attributes_for` on the model works as normal.

### Validations and errors

Nested forms are validated automatically as part of the parent form's `valid?` call. Errors from nested forms are promoted to the parent using structured keys:

- **Collection** — `"line_items[0].name"`, `"line_items[1].quantity"`, …
- **Singular** — `"billing_address.street"`, `"billing_address.city"`, …

### Controller integration

Strong params for HTML forms use the `_attributes` suffix:

```ruby
def order_params
  params.require(:order).permit(
    :customer_name,
    line_items_attributes:      [:id, :name, :quantity, :_destroy],
    billing_address_attributes: [:street, :city, :postcode]
  )
end
```

For API endpoints that send params without the suffix, use plain nested keys instead:

```ruby
def order_params
  params.require(:order).permit(
    :customer_name,
    line_items:      [:name, :quantity],
    billing_address: [:street, :city, :postcode]
  )
end
```

### Initialising the form with pre-built nested records

When rendering a new-record form, build the nested records on the resource before passing it to the form so that `fields_for` / `simple_fields_for` has objects to iterate over:

```ruby
def new
  order = Order.new
  order.line_items.build       # collection — build at least one blank item
  order.build_billing_address  # singular

  @form = CreateOrderForm.new(order, current_user)
end
```

```erb
<%= form_with model: @form, url: orders_path do |f| %>
  <%= f.text_field :customer_name %>

  <%= f.fields_for :line_items do |lf| %>
    <%= lf.text_field :name %>
    <%= lf.number_field :quantity %>
  <% end %>

  <%= f.fields_for :billing_address do |af| %>
    <%= af.text_field :street %>
    <%= af.text_field :city %>
    <%= af.text_field :postcode %>
  <% end %>

  <%= f.submit %>
<% end %>
```

### SimpleForm support

Nested form objects returned by `nested_attributes_for` / `nested_attribute_for` are compatible with [simple_form](https://github.com/heartcombo/simple_form). The anonymous class created by an inline block is given a synthetic `model_name` so that SimpleForm can infer input names and error wrappers correctly.

Use `simple_fields_for` in place of `fields_for` and `f.input` in place of the individual field helpers:

```erb
<%= simple_form_for @form, url: orders_path do |f| %>
  <%= f.input :customer_name %>

  <%= f.simple_fields_for :line_items do |lf| %>
    <%= lf.input :name %>
    <%= lf.input :quantity %>
  <% end %>

  <%= f.simple_fields_for :billing_address do |af| %>
    <%= af.input :street %>
    <%= af.input :city %>
    <%= af.input :postcode %>
  <% end %>

  <%= f.submit %>
<% end %>
```

Validation errors on nested fields are promoted to the parent form with structured keys (e.g. `"line_items[0].name"`), which SimpleForm resolves back to the correct field and renders inline error messages automatically.

## Collections

Use `collection_for` to declare collection-backed select fields on your form, with optional inclusion validation.

```ruby
class CreatePostForm < WellFormed::ResourceForm
  resource_alias :post

  attribute :user_id, :integer

  collection_for :user_id, validate: true do
    User.order(:name)
  end
end
```

`collection_for` generates a `collection_for_<name>` instance method that returns an ActiveRecord relation. The block is evaluated in the context of the form instance, so `user`, `resource`, and any other instance methods are available — useful for scoping:

```ruby
collection_for :user_id do
  User.where(organisation: resource.organisation)
end
```

### Validation

Pass `validate: true` to automatically validate that the submitted value exists within the collection, matched by `:id`:

```ruby
collection_for :user_id, validate: true do
  User.order(:name)
end
```

Validation uses `collection.where(id: value).pluck(:id)` — a single scoped query rather than loading all records into memory. Blank values are always accepted (`allow_blank: true`); pair with a `presence` validator when the field is required.

To match on a field other than `:id`, pass the field name:

```ruby
collection_for :status, validate: :code do
  Status.active
end
```

### Code-to-value resolution (`resolves_to:`)

Use `resolves_to:` when the form accepts one representation of a value (e.g. a code string or an integer id) but the resource stores a different one. After validation, the attribute is automatically replaced with the resolved value via a `validate` callback.

`resolves_to:` requires `validate:` to be a Symbol — the field used to look up the record. If the lookup fails, an `:inclusion` error is added and no transformation is applied.

#### Code → id

The form accepts a code string; the resource stores the integer id:

```ruby
class CreatePostForm < WellFormed::ResourceForm
  resource_alias :post

  attribute :user_id  # untyped — accepts a code string initially

  collection_for :user_id, validate: :code, resolves_to: :id do
    User.all
  end
end

# Submitting "ALICE" resolves to user.id and saves that integer
form = CreatePostForm.new(Post.new, current_user, { user_id: "ALICE" })
form.save  # post.user_id == 42
```

`resolves_to: true` is shorthand for `resolves_to: :id`.

#### Id → code

The form accepts an integer id; the resource stores the code string:

```ruby
class CreatePostForm < WellFormed::ResourceForm
  resource_alias :post

  attribute :user_code  # untyped — accepts an id initially

  collection_for :user_code, validate: :id, resolves_to: :code do
    User.all
  end
end

# Submitting 42 resolves to user.code and saves that string
form = CreatePostForm.new(Post.new, current_user, { user_code: 42 })
form.save  # post.user_code == "ALICE"
```

#### Edit forms

For both directions, `resource_defaults` is automatically overridden to reverse-populate the attribute with the *input* representation when loading an existing record — so the form pre-fills with the value the user expects to see and edit:

```ruby
# Code → id form: post.user_id is 42, form pre-fills user_id with "ALICE"
form = CreatePostForm.new(existing_post, current_user)
form.user_id  # => "ALICE"

# Id → code form: post.user_code is "ALICE", form pre-fills user_code with 42
form = CreatePostForm.new(existing_post, current_user)
form.user_code  # => 42
```

### View integration

Use `collection_for_<name>` directly in the view to build the select:

```erb
<%= f.collection_select :user_id, @form.collection_for_user_id, :id, :name, { include_blank: true } %>
```

### SimpleForm integration

With SimpleForm, pass the collection explicitly via the `collection:` option:

```erb
<%= f.input :user_id, collection: @form.collection_for_user_id %>
```

Alternatively, define a custom SimpleForm input that auto-discovers `collection_for_<name>` on the form object, so the view needs no explicit collection reference:

```ruby
# app/inputs/collection_for_input.rb
class CollectionForInput < SimpleForm::Inputs::CollectionSelectInput
  def collection
    if object.respond_to?(:"collection_for_#{attribute_name}")
      @collection ||= object.public_send(:"collection_for_#{attribute_name}")
    else
      super
    end
  end
end
```

Then declare the field with `as: :collection_for`:

```erb
<%= f.input :user_id, as: :collection_for %>
```

## PORO support

When the resource is a plain Ruby object that does not respond to `save` — a value object, a service-layer struct, an API client payload — inherit from `WellFormed::Struct` instead. It has the same interface as `WellFormed::ResourceForm` but replaces the default `save` behaviour with a `perform` method you define yourself.

Form attributes are still auto-assigned to the resource (via individual setters), and `before_save`/`after_save` callbacks still work. The AR-specific helpers `after_save_commit` and `save_within_transaction` are not available.

```ruby
class CreateInvoiceForm < WellFormed::Struct
  resource_alias :invoice

  attribute :recipient_email, :string
  attribute :amount_cents,    :integer

  validates :recipient_email, presence: true
  validates :amount_cents,    numericality: { greater_than: 0 }

  after_validation :normalise_email
  after_save        :log_issuance

  private

  def perform
    InvoiceService.issue(invoice)
  end

  def normalise_email
    self.recipient_email = recipient_email&.strip&.downcase
  end

  def log_issuance
    Rails.logger.info("Invoice issued to #{recipient_email}")
  end
end
```

`submit` works the same way — it runs validations, assigns attributes to the resource, calls `perform`, and returns the resource on success or `false` on failure.

If there's no meaningful resource to wrap at all, use `WellFormed::ActionForm` instead.

## Translations

WellFormed adds a generic base error when a save or perform fails with no errors already present. The default messages can be overridden in your application's locale files under the form's `resource_alias` key:

```yaml
en:
  activemodel:
    errors:
      models:
        article:                          # matches resource_alias :article
          could_not_be_saved: "could not be saved"
        publish_article:                  # matches resource_alias :publish_article
          could_not_be_performed: "could not be performed"
```

To override globally for all forms, use the shared messages scope:

```yaml
en:
  activemodel:
    errors:
      messages:
        could_not_be_saved: "could not be saved"
        could_not_be_performed: "could not be performed"
```

## Simple variants

Each base class has a **Simple** counterpart that drops the `user` argument from the constructor — useful in contexts where there is no current user, such as background jobs, microservices, or data-import pipelines.

| With user | Without user | Constructor |
|-----------|--------------|-------------|
| `WellFormed::ResourceForm` | `WellFormed::SimpleResource` | `(resource, params = {})` |
| `WellFormed::ActionForm`   | `WellFormed::SimpleAction`   | `(resource, params = {})` |
| `WellFormed::Struct`       | `WellFormed::SimpleStruct`   | `(resource, params = {})` |

Everything else — attributes, validations, callbacks, collections, nested attributes — works identically. Calling `form.user` on a Simple class raises `NoMethodError`.

```ruby
class SyncProductForm < WellFormed::SimpleResource
  resource_alias :product

  attribute :name,  :string
  attribute :price, :decimal

  validates :name,  presence: true
  validates :price, numericality: { greater_than: 0 }
end

form = SyncProductForm.new(Product.new, { name: "Widget", price: 9.99 })
form.save  # => true / false
```

### `WellFormed::WithUser`

If you need to add user support to a custom class that already inherits from one of the Simple variants, prepend `WellFormed::WithUser`. It overrides the constructor to accept `(resource, user, params = {})` and exposes `form.user`:

```ruby
class AuditedSyncForm < WellFormed::SimpleResource
  prepend WellFormed::WithUser

  before_save { AuditLog.record(user, resource) }
end

form = AuditedSyncForm.new(record, current_user, params)
form.user  # => current_user
```

`ResourceForm`, `ActionForm`, and `Struct` are themselves implemented this way — they inherit from their Simple counterpart and prepend `WithUser`.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/resource_form. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/resource_form/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ResourceForm project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/resource_form/blob/main/CODE_OF_CONDUCT.md).
