# frozen_string_literal: true

RSpec.describe "Turbo-friendly redirects", :app_integration do
  around do |example|
    original = Hanami::Turbo.config.see_other_redirects
    example.run
  ensure
    Hanami::Turbo.config.see_other_redirects = original
  end

  before do
    write_app
    write_action "books/update", handle: %(res.redirect_to "/books")
    write_action "books/destroy", handle: %(res.redirect_to "/books", status: 301)
    boot_app
  end

  %w[POST PATCH PUT DELETE].each do |method|
    it "redirects #{method} requests with 303 See Other" do
      response = call_action("books/update", method:)

      expect(response.status).to eq 303
      expect(response.headers["Location"]).to eq "/books"
    end
  end

  it "redirects GET requests with 302" do
    expect(call_action("books/update").status).to eq 302
  end

  it "respects an explicit status" do
    expect(call_action("books/destroy", method: "DELETE").status).to eq 301
  end

  it "can be disabled" do
    Hanami::Turbo.config.see_other_redirects = false

    expect(call_action("books/update", method: "PATCH").status).to eq 302
  end
end
