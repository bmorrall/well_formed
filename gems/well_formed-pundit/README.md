# well_formed-pundit

[Pundit](https://github.com/varvet/pundit) authorization integration for [WellFormed](https://github.com/bmorrall/well_formed) form objects.

Adds `policy`, `authorize!`, and `policy_scope` helpers directly to any WellFormed form, using the form's built-in `resource` and `user` references.

## Installation

```bash
bundle add well_formed-pundit
```

## Usage

Require the gem in your application:

```ruby
require "well_formed-pundit"
```

`WellFormed::Pundit` is automatically included into all WellFormed forms — no `include` required.

### `authorize!`

Raise `Pundit::NotAuthorizedError` if the user is not permitted to perform an action on the resource:

```ruby
class CreateArticleForm < WellFormed::ResourceForm
  resource_alias :article

  attribute :title, :string
  attribute :body,  :string

  validates :title, presence: true

  def perform
    authorize!(:create?)                  # authorizes resource
    authorize!(parent_record, :update?)   # authorizes a different record
    # proceed with save ...
  end
end
```

### `policy`

Access the resolved Pundit policy instance directly. Defaults to the form's `resource`, but accepts an optional record argument:

```ruby
form.policy           # => ArticlePolicy for resource
form.policy.create?   # => true / false
form.policy(other)    # => policy resolved for a different record
```

### `policy_scope`

Resolve a scoped collection for the current user:

```ruby
articles = form.policy_scope(Article.all)
```

## API

| Method | Description |
|--------|-------------|
| `policy(record = resource)` | Returns the Pundit policy instance for `record` and `user` |
| `authorize!(query)` | Raises `Pundit::NotAuthorizedError` unless the user is authorized for `resource` |
| `authorize!(record, query)` | Raises `Pundit::NotAuthorizedError` unless the user is authorized for `record` |
| `policy_scope(collection)` | Returns the policy scope resolved for `user` |

## License

MIT
