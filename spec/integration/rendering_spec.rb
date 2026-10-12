# frozen_string_literal: true

RSpec.describe "Turbo-aware rendering", :app_integration do
  def write_create_action
    write_action "books/create"
    write "app/templates/books/create.html.erb", "<p>html</p>"
  end

  context "Turbo Stream request, view with a turbo_stream template" do
    before do
      write_app
      write_create_action
      write "app/templates/books/create.turbo_stream.erb", "<turbo-stream></turbo-stream>"
      boot_app
    end

    it "renders the stream template without a layout" do
      response = call_action("books/create", method: "POST", accept: AppIntegration::TURBO_STREAM_ACCEPT)

      expect(response.status).to eq 200
      expect(response.headers["Content-Type"]).to start_with "text/vnd.turbo-stream.html"
      expect(body_of(response)).to eq "<turbo-stream></turbo-stream>"
    end

    it "renders HTML in the layout for ordinary requests" do
      response = call_action("books/create", method: "POST")

      expect(response.headers["Content-Type"]).to start_with "text/html"
      expect(body_of(response)).to eq "<html><body><p>html</p></body></html>\n"
    end
  end

  context "Turbo Stream request, view without a turbo_stream template" do
    before do
      write_app
      write_create_action
      boot_app
    end

    it "falls back to HTML in the layout, with an HTML content type" do
      response = call_action("books/create", method: "POST", accept: AppIntegration::TURBO_STREAM_ACCEPT)

      expect(response.headers["Content-Type"]).to start_with "text/html"
      expect(body_of(response)).to eq "<html><body><p>html</p></body></html>\n"
    end
  end

  context "explicit format given to res.render" do
    before do
      write_app
      write_action "books/create", handle: "res.render(view, format: :html)"
      write "app/templates/books/create.html.erb", "<p>html</p>"
      write "app/templates/books/create.turbo_stream.erb", "<turbo-stream></turbo-stream>"
      boot_app
    end

    it "is respected" do
      response = call_action("books/create", method: "POST", accept: AppIntegration::TURBO_STREAM_ACCEPT)

      expect(body_of(response)).to eq "<html><body><p>html</p></body></html>\n"
    end
  end

  context "app restricting accepted formats" do
    before do
      write_app(app_config: <<~RUBY)
        config.actions.formats.accept :html
        Hanami::Turbo.install(config)
      RUBY
      write_create_action
      write "app/templates/books/create.turbo_stream.erb", "<turbo-stream></turbo-stream>"
      boot_app
    end

    it "accepts turbo_stream alongside the app's formats" do
      expect(TestApp::App.config.actions.formats.accepted).to eq [:html, :turbo_stream]

      response = call_action("books/create", method: "POST", accept: AppIntegration::TURBO_STREAM_ACCEPT)
      expect(body_of(response)).to eq "<turbo-stream></turbo-stream>"

      response = call_action("books/create", method: "POST")
      expect(body_of(response)).to eq "<html><body><p>html</p></body></html>\n"
    end
  end

  context "app accepting any format" do
    before do
      write_app
      write_action "books/index"
      write "app/templates/books/index.html.erb", "books"
      boot_app
    end

    it "keeps accepting any format" do
      expect(TestApp::App.config.actions.formats.accepted).to eq [:all, :turbo_stream]
      expect(TestApp::App.config.actions.formats.default).to be_nil

      response = call_action("books/index", accept: "application/json")
      expect(response.status).to eq 200

      response = call_action("books/index", accept: "*/*")
      expect(response.status).to eq 200
    end
  end

  describe "Turbo Frame requests" do
    around do |example|
      original = Hanami::Turbo.config.frame_layout
      example.run
    ensure
      Hanami::Turbo.config.frame_layout = original
    end

    before do
      write_app
      write_action "books/show"
      write "app/templates/books/show.html.erb", %(<turbo-frame id="book">book</turbo-frame>)
      write "app/templates/layouts/frame.html.erb", "<frame-layout><%= yield %></frame-layout>"
      boot_app
    end

    let(:frame_headers) { {"HTTP_TURBO_FRAME" => "book"} }

    it "renders in the app layout by default" do
      response = call_action("books/show", headers: frame_headers)

      expect(body_of(response)).to eq %(<html><body><turbo-frame id="book">book</turbo-frame></body></html>\n)
    end

    it "renders without a layout when frame_layout is false" do
      Hanami::Turbo.config.frame_layout = false

      response = call_action("books/show", headers: frame_headers)

      expect(body_of(response)).to eq %(<turbo-frame id="book">book</turbo-frame>)
    end

    it "renders in the configured frame layout" do
      Hanami::Turbo.config.frame_layout = "frame"

      response = call_action("books/show", headers: frame_headers)

      expect(body_of(response)).to eq %(<frame-layout><turbo-frame id="book">book</turbo-frame></frame-layout>)
    end

    it "uses the frame layout when a frame's form submission falls back to HTML" do
      Hanami::Turbo.config.frame_layout = "frame"

      # Forms inside frames accept streams; this view has no stream template.
      response = call_action("books/show", method: "POST", accept: AppIntegration::TURBO_STREAM_ACCEPT, headers: frame_headers)

      expect(response.headers["Content-Type"]).to start_with "text/html"
      expect(body_of(response)).to eq %(<frame-layout><turbo-frame id="book">book</turbo-frame></frame-layout>)
    end

    it "uses the app layout for non-frame requests" do
      Hanami::Turbo.config.frame_layout = false

      response = call_action("books/show")

      expect(body_of(response)).to start_with "<html>"
    end
  end

  describe "error responses to Turbo Stream requests" do
    before do
      write_app
      write_action "books/update", handle: <<~RUBY
        case req.params[:case]
        when "halt" then halt 404
        when "stream" then res.status = 422; res.render(view)
        when "manual" then res.status = 422; res.body = "<turbo-stream action='remove' target='x'></turbo-stream>"
        end
      RUBY
      write "app/templates/books/update.turbo_stream.erb", "<turbo-stream></turbo-stream>"
      boot_app
    end

    def update(kase)
      call_action("books/update", method: "PATCH", accept: AppIntegration::TURBO_STREAM_ACCEPT, params: {"QUERY_STRING" => "case=#{kase}"})
    end

    it "sends halted errors as HTML, so Turbo shows them rather than ignoring them" do
      response = update("halt")

      expect(response.status).to eq 404
      expect(response.headers["Content-Type"]).to start_with "text/html"
    end

    it "keeps rendered stream errors as streams" do
      response = update("stream")

      expect(response.status).to eq 422
      expect(response.headers["Content-Type"]).to start_with "text/vnd.turbo-stream.html"
    end

    it "keeps hand-written stream bodies as streams" do
      response = update("manual")

      expect(response.headers["Content-Type"]).to start_with "text/vnd.turbo-stream.html"
    end
  end
end
