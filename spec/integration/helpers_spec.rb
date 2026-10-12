# frozen_string_literal: true

RSpec.describe "Turbo view helpers", :app_integration do
  before do
    write_app(layout: "<%= yield %>")
    write "app/book.rb", <<~RUBY
      module TestApp
        Book = Struct.new(:id, :title, keyword_init: true)
      end
    RUBY
  end

  def render_stream(template, view_body: "expose(:book, decorate: true) { TestApp::Book.new(id: 42, title: 'Dune') }")
    write_action "books/create", view_body: view_body
    write "app/templates/books/create.html.erb", ""
    write "app/templates/books/create.turbo_stream.erb", template
    boot_app

    body_of(call_action("books/create", method: "POST", accept: AppIntegration::TURBO_STREAM_ACCEPT))
  end

  describe "turbo_stream" do
    it "builds content actions targeting a record" do
      output = render_stream(%(<%= turbo_stream.replace book, "<b>new</b>" %>))

      expect(output).to eq %(<turbo-stream action="replace" target="book_42"><template>&lt;b&gt;new&lt;/b&gt;</template></turbo-stream>)
    end

    it "takes block content" do
      output = render_stream(<<~ERB.chomp)
        <%= turbo_stream.append "books" do %><li><%= book.title %></li><% end %>
      ERB

      expect(output).to eq %(<turbo-stream action="append" target="books"><template><li>Dune</li></template></turbo-stream>)
    end

    it "renders partials" do
      write "app/templates/books/_book.html.erb", %(<li id="<%= book.dom_id %>"><%= book.title %></li>)

      output = render_stream(%(<%= turbo_stream.prepend "books", partial: "books/book", locals: {book: book} %>))

      expect(output).to eq %(<turbo-stream action="prepend" target="books"><template><li id="book_42">Dune</li></template></turbo-stream>)
    end

    it "renders nested partials of HTML partials as HTML" do
      write "app/templates/books/_book.html.erb", %(<li><%= render "books/title", title: book.title %></li>)
      write "app/templates/books/_title.html.erb", %(<b><%= title %></b>)

      output = render_stream(%(<%= turbo_stream.append "books", partial: "books/book", locals: {book: book} %>))

      expect(output).to include "<template><li><b>Dune</b></li></template>"
    end

    it "prefers a partial in the turbo_stream format" do
      write "app/templates/books/_book.html.erb", "html partial"
      write "app/templates/books/_book.turbo_stream.erb", "stream partial"

      output = render_stream(%(<%= turbo_stream.update book, partial: "books/book", locals: {book: book} %>))

      expect(output).to include "<template>stream partial</template>"
    end

    it "supports remove, targets and morph" do
      output = render_stream(<<~ERB.chomp)
        <%= turbo_stream.remove book %><%= turbo_stream.update_all ".count", "3" %><%= turbo_stream.replace "x", "y", method: :morph %>
      ERB

      expect(output).to eq [
        %(<turbo-stream action="remove" target="book_42"></turbo-stream>),
        %(<turbo-stream action="update" targets=".count"><template>3</template></turbo-stream>),
        %(<turbo-stream action="replace" target="x" method="morph"><template>y</template></turbo-stream>)
      ].join
    end

    it "builds refresh streams" do
      output = render_stream(%(<%= turbo_stream.refresh %><%= turbo_stream.refresh(request_id: "abc") %>))

      expect(output).to eq %(<turbo-stream action="refresh"></turbo-stream><turbo-stream action="refresh" request-id="abc"></turbo-stream>)
    end

    it "escapes targets" do
      output = render_stream(%(<%= turbo_stream.remove %q("><script>) %>))

      expect(output).to eq %(<turbo-stream action="remove" target="&quot;&gt;&lt;script&gt;"></turbo-stream>)
    end
  end

  describe "turbo_frame_tag and dom_id" do
    def render_html(template, view_body: "expose(:book, decorate: true) { TestApp::Book.new(id: 42, title: 'Dune') }\nexpose(:new_book, decorate: true) { TestApp::Book.new }\nexpose(:raw_book) { TestApp::Book.new(id: 7) }")
      write_action "books/show", view_body: view_body
      write "app/templates/books/show.html.erb", template
      boot_app

      body_of(call_action("books/show"))
    end

    it "builds frames from ids and records" do
      output = render_html(<<~ERB.chomp)
        <%= turbo_frame_tag "tray" do %>in<% end %>|<%= turbo_frame_tag book %>|<%= turbo_frame_tag book, :comments, src: "/c", loading: :lazy %>
      ERB

      expect(output).to eq [
        %(<turbo-frame id="tray">in</turbo-frame>),
        %(<turbo-frame id="book_42"></turbo-frame>),
        %(<turbo-frame id="comments_book_42" src="/c" loading="lazy"></turbo-frame>)
      ].join("|")
    end

    it "builds dom ids and classes in templates and parts" do
      output = render_html(<<~ERB.chomp)
        <%= dom_id(book) %> <%= dom_id(book, :edit) %> <%= dom_id(new_book) %> <%= dom_id(new_book, :edit) %> <%= dom_class(book) %> <%= book.dom_id(:row) %> <%= new_book.dom_class %> <%= dom_id(raw_book) %>
      ERB

      expect(output).to eq "book_42 edit_book_42 new_book edit_book book row_book_42 book book_7"
    end
  end

  describe "button_to and confirmations" do
    def render_html(template)
      write_app(layout: "<%= yield %>", app_config: <<~RUBY)
        config.actions.sessions = :cookie, {secret: "x" * 64}
        Hanami::Turbo.install(config)
      RUBY
      write_action "books/show"
      write "app/templates/books/show.html.erb", template
      boot_app

      body_of(call_action("books/show"))
    end

    it "renders a form with a single submit button, POST by default" do
      output = render_html(%(<%= button_to "Archive", "/books/1/archive" %>))

      form_tag = output[/\A<form[^>]*>/]
      expect(form_tag).to include %(action="/books/1/archive"), %(method="POST"), %(class="button_to")
      expect(output).not_to include "_method"
      expect(output).to include %(<input type="hidden" name="_csrf_token" value=")
      expect(output).to end_with %(<button type="submit">Archive</button></form>)
    end

    it "overrides the method, and puts turbo_confirm on the button" do
      output = render_html(%(<%= button_to "Delete", "/books/1", method: :delete, data: {turbo_confirm: "Delete Dune?"} %>))

      expect(output).to include %(<input type="hidden" name="_method" value="DELETE">)
      expect(output).to include %(<button type="submit" data-turbo-confirm="Delete Dune?">Delete</button>)
    end

    it "takes form attributes, extra params and block content" do
      output = render_html(<<~ERB.chomp)
        <%= button_to "/books/1", method: :delete, form: {class: "inline", data: {turbo_confirm: "Sure?"}}, params: {return_to: "/books"}, class: "danger" do %><b>Delete</b><% end %>
      ERB

      expect(output).to include %(class="inline")
      expect(output).to include %(data-turbo-confirm="Sure?")
      expect(output).not_to include "button_to"
      expect(output).to include %(<input type="hidden" name="return_to" value="/books">)
      expect(output).to end_with %(<button type="submit" class="danger"><b>Delete</b></button></form>)
    end

    it "escapes confirmation messages and content" do
      output = render_html(%(<%= button_to "<i>x</i>", "/x", data: {turbo_confirm: %q(Delete "Dune" & more?)} %>))

      expect(output).to include %(data-turbo-confirm="Delete &quot;Dune&quot; &amp; more?")
      expect(output).to include "&lt;i&gt;x&lt;/i&gt;"
    end

    it "lets links make non-GET requests with confirmation" do
      output = render_html(%(<%= link_to "Delete", "/books/1", data: {turbo_method: :delete, turbo_confirm: "Sure?"} %>))

      expect(output).to eq %(<a data-turbo-method="delete" data-turbo-confirm="Sure?" href="/books/1">Delete</a>)
    end
  end
end
