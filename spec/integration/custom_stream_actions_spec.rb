# frozen_string_literal: true

# Custom stream actions, added the way turbo-rails apps add them to Turbo::Streams::TagBuilder.
module CustomStreamActionsSpec
  module Actions
    # Targetless, attributes only.
    def toast(message, level: "info")
      action(:toast, nil, message:, level:)
    end

    # Written exactly as in a turbo-rails app, to check modules can be ported unchanged.
    def console_log(message)
      turbo_stream_action_tag :console_log, message: message
    end

    # Targeted, with content from a partial.
    def highlight(target, **options)
      action(:highlight, target, **options)
    end
  end
end

Hanami::Turbo::StreamBuilder.include(CustomStreamActionsSpec::Actions)

RSpec.describe "Custom Turbo Stream actions", :app_integration do
  def render_stream(template)
    write_app(layout: "<%= yield %>")
    write "app/book.rb", <<~RUBY
      module TestApp
        Book = Struct.new(:id, :title, keyword_init: true)
      end
    RUBY
    write_action "books/create", view_body: "expose(:book) { TestApp::Book.new(id: 42, title: 'Dune') }"
    write "app/templates/books/create.html.erb", ""
    write "app/templates/books/create.turbo_stream.erb", template
    write "app/templates/books/_flash.html.erb", "<p><%= title %></p>"
    boot_app

    body_of(call_action("books/create", method: "POST", accept: AppIntegration::TURBO_STREAM_ACCEPT))
  end

  it "supports actions added by a module, with no target or template" do
    output = render_stream(%(<%= turbo_stream.toast "Saved", level: "success" %>))

    expect(output).to eq %(<turbo-stream action="toast" message="Saved" level="success"></turbo-stream>)
  end

  it "supports modules written for turbo-rails, using turbo_stream_action_tag" do
    output = render_stream(%(<%= turbo_stream.console_log "hi" %>))

    expect(output).to eq %(<turbo-stream action="console_log" message="hi"></turbo-stream>)
  end

  it "supports custom actions with targets and partials" do
    output = render_stream(%(<%= turbo_stream.highlight book, partial: "books/flash", locals: {title: book.title}, duration: 500 %>))

    expect(output).to eq %(<turbo-stream action="highlight" target="book_42" duration="500"><template><p>Dune</p></template></turbo-stream>)
  end

  it "provides turbo_stream_action_tag as a view helper, with target, targets and template" do
    output = render_stream(<<~ERB.chomp)
      <%= turbo_stream_action_tag :notify, target: book, template: "<b>hi</b>".html_safe %><%= turbo_stream_action_tag :notify, targets: ".books", data: {count: 2} %>
    ERB

    expect(output).to eq [
      %(<turbo-stream action="notify" target="book_42"><template><b>hi</b></template></turbo-stream>),
      %(<turbo-stream action="notify" targets=".books" data-count="2"></turbo-stream>)
    ].join
  end

  it "supports one-off custom actions without a module" do
    output = render_stream(%(<%= turbo_stream.action :scroll_to, book, behavior: "smooth" %>))

    expect(output).to eq %(<turbo-stream action="scroll_to" target="book_42" behavior="smooth"></turbo-stream>)
  end

  it "still renders an empty template for built-in content actions" do
    output = render_stream(%(<%= turbo_stream.update "count", "" %>))

    expect(output).to eq %(<turbo-stream action="update" target="count"><template></template></turbo-stream>)
  end
end
