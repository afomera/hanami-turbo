# hanami-turbo

[Hotwire Turbo](https://turbo.hotwired.dev) support for Hanami apps.

- Renders `.turbo_stream` templates for Turbo Stream requests (without a layout), falling back to
  HTML when a view has no stream template.
- A `turbo_stream` builder, `turbo_frame_tag`, and `dom_id`/`dom_class` helpers for templates.
- `button_to`, for buttons that submit (with Turbo confirmations, like Rails).
- `303 See Other` redirects after non-GET requests, as Turbo requires.
- Optional lighter layouts for Turbo Frame requests.

Built against the main branches of Hanami and its gems. See
[hanami-turbo-example](../hanami-turbo-example) for a complete app using every feature.

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
<%= csrf_meta_tags&.html_safe %>
<%= javascript_tag "app", defer: true %>
```

Load the script in `<head>` (with `defer`), not at the end of `<body>`: Turbo replaces the body on
each visit, and would otherwise evaluate it again.

On Hanami main, `csrf_meta_tags` returns a string that isn't marked HTML safe, so it is escaped
unless you call `html_safe` as above. (Sessions must be enabled for CSRF tokens to exist.)

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

A common shape for actions that respond to Turbo with streams, and redirect everyone else:

```ruby
def handle(request, response)
  book = book_repo.create(request.params[:book])

  if request.turbo_stream?
    response.render(view, book:)   # renders create.turbo_stream.erb
  else
    response.redirect_to routes.path(:books)
  end
end
```

Error responses that weren't rendered from a stream template (such as `halt 404`) are sent as HTML
even when the request negotiated a stream, so Turbo shows them instead of silently ignoring them.

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

## Buttons, confirmations and non-GET links

`button_to` renders a one-button form (with the CSRF token, and `_method` for PATCH, PUT and DELETE),
like Rails. Attributes go on the button; `form:` sets the form's own attributes, and `params:` adds
hidden fields.

```erb
<%= button_to "Delete", routes.path(:book, id: book.id),
      method: :delete,
      data: {turbo_confirm: "Delete #{book.title}?"} %>

<%= button_to "Archive", routes.path(:archive_book, id: book.id), form: {class: "inline"}, params: {return_to: "/books"} %>
```

Turbo asks for confirmation before submitting any form, or form button, with `data-turbo-confirm`.
You can put it on the button (as above) or the form (`form: {data: {turbo_confirm: "..."}}`), as
Rails apps do.

Links can make non-GET requests through Turbo, with or without confirmation, using `link_to`:

```erb
<%= link_to "Delete", routes.path(:book, id: book.id),
      data: {turbo_method: :delete, turbo_confirm: "Are you sure?"} %>
```

Turbo sends these as real `DELETE` (etc.) requests, with the CSRF token from `csrf_meta_tags` in an
`X-CSRF-Token` header. Prefer `button_to` for anything destructive: unlike links, buttons also work
without JavaScript.

### Custom confirmation dialogs

By default Turbo uses the browser's `confirm()`. To show your own dialog, set
`Turbo.config.forms.confirm` to a function returning a promise of true or false:

```erb
<%# in the layout %>
<dialog id="confirm-dialog">
  <form method="dialog">
    <p id="confirm-message"></p>
    <button value="cancel">Cancel</button>
    <button value="confirm" data-confirm-button>Confirm</button>
  </form>
</dialog>
```

```js
import * as Turbo from "@hotwired/turbo";

Turbo.config.forms.confirm = (message, form, submitter) => {
  const dialog = document.getElementById("confirm-dialog");
  dialog.querySelector("#confirm-message").textContent = message;
  dialog.querySelector("[data-confirm-button]").textContent =
    submitter?.dataset.turboConfirmButton || form.dataset.turboConfirmButton || "Confirm";
  dialog.showModal();

  return new Promise((resolve) => {
    dialog.addEventListener("close", () => resolve(dialog.returnValue === "confirm"), { once: true });
  });
};
```

The `data-turbo-confirm-button` attribute is a convention from this snippet (not part of Turbo)
for customising the confirm button's label per button:

```erb
<%= button_to "Delete", path, method: :delete,
      data: {turbo_confirm: "Delete this book?", turbo_confirm_button: "Delete book"} %>
```

(On Turbo 7, use `Turbo.setConfirmMethod(fn)` instead; Turbo 8 deprecates it.)

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
