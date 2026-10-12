# hanami-turbo

[Hotwire Turbo](https://turbo.hotwired.dev) support for Hanami apps.

- Renders `.turbo_stream` templates for Turbo Stream requests (without a layout), falling back to
  HTML when a view has no stream template.
- A `turbo_stream` builder, `turbo_frame_tag`, and `dom_id`/`dom_class` helpers for templates.
- `button_to`, for buttons that submit (with Turbo confirmations, like Rails).
- [Custom stream actions](#custom-stream-actions), added like in turbo-rails
  (`turbo_stream_action_tag` included).
- `303 See Other` redirects after non-GET requests, as Turbo requires.
- Optional lighter layouts for Turbo Frame requests.

Built against the main branches of Hanami and its gems. See
[hanami-turbo-example](https://github.com/afomera/hanami-turbo-example) for a complete app using every feature.

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

Custom actions (your own, beyond Turbo's built-ins) are covered in
[Custom stream actions](#custom-stream-actions) below.

To pick a format yourself, pass it to `render`; explicit options always win:

```ruby
res.render(view, format: :html)
```

## Custom stream actions

Turbo's built-in actions cover changing the DOM, but you can add your own, such as showing a toast,
highlighting an element, or logging to the console. A custom action has two halves:

1. **Ruby**: a method on the `turbo_stream` builder that renders `<turbo-stream action="...">`.
2. **JavaScript**: a function on `Turbo.StreamActions` that runs when that element arrives.

This works the way it does in turbo-rails, and modules written for turbo-rails can be reused as they
are (see [Porting from turbo-rails](#porting-from-turbo-rails)).

### 1. Define the actions

Write a module of methods, and include it into `Hanami::Turbo::StreamBuilder`:

```ruby
# config/turbo_stream_actions.rb
module Bookshelf
  module TurboStreamActions
    # No target: the JavaScript decides where the toast goes.
    def toast(message, level: "info")
      action(:toast, nil, message:, level:)
    end

    # A target: a DOM id string, or a record (turned into an id with dom_id).
    def highlight(target)
      action(:highlight, target)
    end

    # A target and content, rendered from a partial.
    def flash_message(target, message)
      action(:flash_message, target, partial: "shared/flash", locals: {message:})
    end
  end
end

Hanami::Turbo::StreamBuilder.include(Bookshelf::TurboStreamActions)
```

Require it from your app class, so it's loaded before anything renders, whether in the server, the
console, or tests:

```ruby
# config/app.rb
require "hanami"
require "hanami/turbo"
require_relative "turbo_stream_actions"
```

Keep this file out of `app/` and `lib/<your_app>/`: those are autoloaded, and the module is included
once, at boot. Like a Rails initializer, changes need a server restart (code reloading won't pick
them up).

### 2. Use them in stream templates

```erb
<%# app/templates/books/create.turbo_stream.erb %>
<%= turbo_stream.prepend "books", partial: "books/book", locals: {book:} %>
<%= turbo_stream.toast "Added #{book.title}", level: "success" %>
<%= turbo_stream.highlight book %>
```

This renders:

```html
<turbo-stream action="prepend" target="books"><template>...</template></turbo-stream>
<turbo-stream action="toast" message="Added Dune" level="success"></turbo-stream>
<turbo-stream action="highlight" target="book_42"></turbo-stream>
```

For a one-off action, you don't need a module. Use `action` directly, or the
`turbo_stream_action_tag` view helper:

```erb
<%= turbo_stream.action :scroll_to, book, behavior: "smooth" %>
<%= turbo_stream_action_tag :console_log, message: "Hello" %>
```

### 3. Handle them in JavaScript

Register a handler for each action on `StreamActions`. Inside it, `this` is the `<turbo-stream>`
element:

```js
// app/assets/js/stream_actions.js, imported from app.js
import { StreamActions } from "@hotwired/turbo";

StreamActions.toast = function () {
  const toast = document.createElement("div");
  toast.className = `toast toast-${this.getAttribute("level")}`;
  toast.setAttribute("role", "status");
  toast.textContent = this.getAttribute("message");
  document.getElementById("toasts").append(toast);
  setTimeout(() => toast.remove(), 4000);
};

StreamActions.highlight = function () {
  this.targetElements.forEach((element) => element.classList.add("highlight"));
};

StreamActions.flash_message = function () {
  this.targetElements.forEach((element) => element.replaceChildren(this.templateContent));
};
```

Useful properties of the stream element:

| | |
| --- | --- |
| `this.getAttribute("name")` | an attribute you passed from Ruby |
| `this.targetElements` | the elements matching `target` (by id) or `targets` (by CSS selector) |
| `this.templateContent` | a copy of the `<template>` content, if any |

Import the handlers in your entry point (`import "./stream_actions.js"`), so they're registered
before any stream arrives. If no handler is registered for an action, Turbo raises an error in the
browser console.

### The building blocks

Your methods (and templates) can use these builder methods:

| Method | Renders |
| --- | --- |
| `action(name, target, content = nil, **options, &block)` | an action for one target. `target` may be `nil`. |
| `action_all(name, targets, content = nil, **options, &block)` | an action for every element matching the `targets` CSS selector. |
| `turbo_stream_action_tag(name, target: nil, targets: nil, template: nil, **attributes)` | the turbo-rails equivalent, with keyword arguments. |

Inside your methods, `scope` is the scope of the template being rendered, so you can use its
helpers, `routes` and locals, just as turbo-rails methods use `@view_context`:

```ruby
def toast_with_link(message, book)
  action(:toast, nil, message:, href: scope.routes.path(:book, id: book.id))
end
```

How the arguments become HTML:

- **Content** goes in a `<template>`, from (in order of precedence) a block, `partial:` with
  `locals:`, or the `content` argument. Strings are HTML-escaped unless marked safe
  (`.html_safe`). Partials are rendered as stream partials if they exist (`_flash.turbo_stream.erb`),
  and otherwise as HTML (`_flash.html.erb`).
- **A `<template>` is added only when there's content.** Turbo's built-in content actions (`append`,
  `update`, etc.) always get one, since Turbo expects it.
- **Other keyword arguments become attributes**, with their names used as given. `request_id: 1`
  renders `request_id="1"`, so for a dashed name use a string key (`"request-id": 1`). A `data:` hash
  becomes `data-*` attributes, with keys dasherized and non-string values encoded as JSON.
  Attributes with `nil` values are left out, and `true` renders as `"true"`.
- **`partial:`, `locals:` and `method:` are reserved**: the first two supply content, and `method:`
  is the attribute Turbo uses for morphing (`method: :morph`).

### Testing

Custom actions render plain HTML, so request specs can check for them like any other stream:

```ruby
it "shows a toast after creating a book" do
  post "/books", {book: {title: "Dune", author: "Frank Herbert"}},
    {"HTTP_ACCEPT" => "text/vnd.turbo-stream.html, text/html"}

  expect(last_response.body).to include(
    %(<turbo-stream action="toast" message="Added Dune" level="success"></turbo-stream>)
  )
end
```

The JavaScript half needs a browser test (for example with Capybara or Playwright).

### Porting from turbo-rails

| turbo-rails | hanami-turbo |
| --- | --- |
| `Turbo::Streams::TagBuilder.prepend(MyActions)` | `Hanami::Turbo::StreamBuilder.include(MyActions)` |
| Module in `config/initializers/` | Module in `config/`, required from `config/app.rb` |
| `turbo_stream_action_tag :name, target:, targets:, template:, **attributes` | the same |
| `action(:name, target, content)` in TagBuilder methods | the same, plus `partial:`/`locals:` and blocks |
| `@view_context` in TagBuilder methods | `scope`: the template's scope, with its helpers and `routes` |
| `Turbo.StreamActions.name = function () { ... }` | the same (it's Turbo's JavaScript API) |

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
