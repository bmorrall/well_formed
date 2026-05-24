# well_formed-paper_trail

[PaperTrail](https://github.com/paper-trail-gem/paper_trail) versioning integration for [WellFormed](https://github.com/bmorrall/well_formed) form objects.

Automatically sets `PaperTrail.request.whodunnit` to the form's `user` around every `save` and `perform`, so version records are attributed to the correct user without any controller wiring.

## Installation

```bash
bundle add well_formed-paper_trail
```

## Usage

Require the gem in your application:

```ruby
require "well_formed-paper_trail"
```

`WellFormed::PaperTrail` is automatically included into all WellFormed forms — no `include` required. With PaperTrail configured on your models, versions are immediately attributed to the form's `user`:

```ruby
class UpdateArticleForm < WellFormed::ResourceForm
  resource_alias :article

  attribute :title, :string
  attribute :body,  :string

  validates :title, presence: true
end

form = UpdateArticleForm.new(article, current_user, article_params)
form.save
# => PaperTrail::Version created with whodunnit: current_user.id.to_s
```

Works for `ActionForm` too — any model changes made inside `perform` are attributed correctly:

```ruby
class PublishArticleForm < WellFormed::ActionForm
  resource_alias :article

  def perform
    article.publish!   # triggers a PaperTrail version attributed to user
  end
end
```

### Custom whodunnit

By default, `whodunnit` is set to `user&.id&.to_s`. There are two ways to override this.

#### Global default

Set a global proc in an initializer. It receives the form's `user` as its argument:

```ruby
# config/initializers/well_formed_paper_trail.rb
WellFormed::PaperTrail.whodunnit = ->(user) { user&.email }
```

#### Per-form override

Use `paper_trail_whodunnit` to override on a specific form class. The block is evaluated in the context of the form instance, so all form attributes and helpers (including `user`) are available:

```ruby
class UpdateArticleForm < WellFormed::ResourceForm
  paper_trail_whodunnit { user.email }
end
```

```ruby
class AdminUpdateForm < WellFormed::ResourceForm
  paper_trail_whodunnit { "admin:#{user.id}" }
end
```

The per-form macro takes precedence over the global config. It is also inherited by subclasses and can be overridden per subclass:

```ruby
class BaseForm < WellFormed::ResourceForm
  paper_trail_whodunnit { user.email }
end

class AuditedForm < BaseForm
  paper_trail_whodunnit { "#{user.role}:#{user.id}" }  # overrides parent
end
```

The priority order is: **per-form macro → global config → `user&.id&.to_s`**.

## API

| Method | Description |
|--------|-------------|
| `WellFormed::PaperTrail.whodunnit = ->(user) { ... }` | Global default — proc receives `user`, return value used as `whodunnit` |
| `paper_trail_whodunnit { ... }` | Per-form macro — block evaluated on the form instance, takes precedence over global config. Inherits from superclass. |

## How it works

`whodunnit` is set via `PaperTrail.request(whodunnit:) { ... }` inside an `around_save` callback (for `ResourceForm` and `Struct`) or an `around_perform` callback (for `ActionForm`). This is the thread-safe, block-scoped API recommended by PaperTrail — the previous `whodunnit` value is always restored after the block exits, even if an exception is raised.

## License

MIT
