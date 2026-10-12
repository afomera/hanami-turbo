# hanami-turbo

[Hotwire Turbo](https://turbo.hotwired.dev) support for Hanami apps.

- Renders `.turbo_stream` templates for Turbo Stream requests (without a layout), falling back to
  HTML when a view has no stream template.
- A `turbo_stream` builder, `turbo_frame_tag`, and `dom_id`/`dom_class` helpers for templates.
- `303 See Other` redirects after non-GET requests, as Turbo requires.
- Optional lighter layouts for Turbo Frame requests.

Built against the main branches of Hanami and its gems.

## Setup

```ruby
# Gemfile
gem "hanami-turbo"
```

```ruby
# config/app.rb
require "hanami"
require "hanami/turbo"

module Bookshelf
  class App < Hanami::App
    Hanami::Turbo.install(config)
  end
end
```

`install` registers the `turbo_stream` format (`text/vnd.turbo-stream.html`) and adds it to your
accepted formats. If your app accepts any format (the default), it keeps doing so.

Then add Turbo to your JavaScript, and the CSRF meta tags to your layout, so Turbo can send the
token with requests made from links and buttons:

```sh
npm install @hotwired/turbo
```

```js
// app/assets/js/app.js
import "@hotwired/turbo";
```

```erb
<%# app/templates/layouts/app.html.erb, inside <head> %>
<%= csrf_meta_tags %>
<%= javascript_tag "app", defer: true %>
```

## Turbo Streams

Turbo form submissions accept stream responses. When a view has a `.turbo_stream` template, it is
rendered for these requests, with no layout:

```erb
<%# app/templates/books/create.turbo_stream.erb %>
<%= turbo_stream.prepend "books", partial: "books/book", locals: {book:} %>
<%= turbo_stream.update "books_count", books_count.to_s %>
<%= turbo_stream.replace "new_book" do %>
  <%= render "books/form" %>
<% end %>
```

Views without a `.turbo_stream` template render HTML as usual, so you can add stream templates only
where you want them.

Partials render in the stream format when one exists (`_book.turbo_stream.erb`), and otherwise as
HTML, so the same `_book.html.erb` serves full pages and streams.

The builder supports every Turbo action: `append`, `prepend`, `replace`, `update`, `before`,
`after`, `remove` and `refresh`, plus `*_all` variants that take a CSS selector (`update_all
".count", "3"`), `method: :morph`, and `action(:custom_action, target, ...)` for custom actions.
Targets can be strings or records.

To pick a format yourself, pass it to `render`; explicit options always win:

```ruby
res.render(view, format: :html)
```

## Turbo Frames

```erb
<%= turbo_frame_tag "tray" do %>...<% end %>
<%= turbo_frame_tag book %>                       <%# id="book_42" %>
<%= turbo_frame_tag book, :comments, src: routes.path(:book_comments, id: book.id), loading: :lazy %>
```

Turbo only uses the matching `<turbo-frame>` from a frame request's response. To skip rendering the
full layout for these requests:

```ruby
Hanami::Turbo.config.frame_layout = false     # no layout
Hanami::Turbo.config.frame_layout = "frame"   # or a lighter layout, e.g. one with just <head>
```

In actions, `req.turbo_frame` returns the requesting frame's id, and `req.turbo_frame?` and
`req.turbo_stream?` tell you what kind of Turbo request you have.

## DOM ids

`dom_id` and `dom_class` name records after their class, for use as frame ids and stream targets:

```erb
<%= dom_id(book) %>          <%# "book_42" %>
<%= dom_id(book, :edit) %>   <%# "edit_book_42" %>
<%= dom_id(Book.new) %>      <%# "new_book" %>
```

Decorated parts also respond to `dom_id` and `dom_class` directly: `<li id="<%= book.dom_id %>">`.

## Forms and redirects

Turbo expects:

- **A redirect after a successful submission.** For non-GET requests, `res.redirect_to` now defaults
  to `303 See Other`. Browsers repeat PATCH and DELETE requests when following a 302, so this is
  required for those; for POST it behaves the same as a 302. An explicit `status:` is always kept.
  To turn this off: `Hanami::Turbo.config.see_other_redirects = false`.
- **A 4xx status when re-rendering a form with errors.** Turbo ignores a `200` response to a form
  submission, so set `res.status = 422` before rendering.

## How it works

The gem extends Hanami at public extension points where it can: it prepends `Response#render` and
`Response#redirect_to`, includes helpers into the standard Hanami view helpers, and adds methods to
`Request` and `View::Part`. The few calls into hanami-view's private API (checking a template
exists, and rendering a partial in another format) are kept in `Hanami::Turbo::ViewInternals`.

## License

MIT
