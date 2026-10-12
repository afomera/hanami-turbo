# frozen_string_literal: true

require "dry/configurable"
require "dry/inflector"
require "hanami"
require "hanami/action"
require "hanami/view"

require_relative "turbo/version"

module Hanami
  # Hotwire Turbo support for Hanami apps.
  #
  # Requiring this file extends `Hanami::Action::Request`, `Hanami::Action::Response`,
  # `Hanami::View::Part` and the standard Hanami view helpers. Call {.install} from your app class to
  # register the Turbo Stream format.
  #
  # @example
  #   # config/app.rb
  #   require "hanami"
  #   require "hanami/turbo"
  #
  #   module Bookshelf
  #     class App < Hanami::App
  #       Hanami::Turbo.install(config)
  #     end
  #   end
  #
  # @api public
  module Turbo
    extend Dry::Configurable

    # The format name for Turbo Stream responses.
    FORMAT = :turbo_stream

    # The media type Turbo sends in `Accept` headers and expects on stream responses.
    MEDIA_TYPE = "text/vnd.turbo-stream.html"

    # @!attribute [rw] see_other_redirects
    #   Whether `res.redirect_to` defaults to `303 See Other` for non-GET requests. Turbo requires a
    #   303 after PATCH, PUT and DELETE form submissions, since browsers repeat the original method
    #   when following a 302. An explicitly given `status:` is always respected.
    #
    #   Defaults to true.
    setting :see_other_redirects, default: true

    # @!attribute [rw] frame_layout
    #   The layout to use when rendering HTML for a request made by a Turbo Frame (one with a
    #   `Turbo-Frame` header). Turbo only uses the matching `<turbo-frame>` from these responses, so
    #   rendering the full layout is wasted work.
    #
    #   `nil` (the default) leaves the view's layout unchanged. `false` renders no layout. A string
    #   names a layout within the view's `layouts_dir`.
    setting :frame_layout, default: nil

    # Registers the `:turbo_stream` format with the given app config.
    #
    # `:turbo_stream` is added to the app's accepted formats, so that Turbo's `Accept` header
    # negotiates a stream response. Apps that accept any format (the default) also get the `:all`
    # format, which keeps them accepting any format, so installing Turbo never causes new 406
    # responses.
    #
    # @param config [Hanami::Config] the app's config
    #
    # @return [void]
    #
    # @api public
    def self.install(config)
      formats = config.actions.formats
      formats.register(FORMAT, MEDIA_TYPE)

      # Assign `accepted` directly rather than using `accept`, which would make the first format the
      # default response format.
      formats.accepted = (formats.accepted.empty? ? [:all] : formats.accepted) | [FORMAT]
    end

    # @api private
    def self.inflector
      @inflector ||= Dry::Inflector.new
    end
  end
end

require_relative "turbo/view_internals"
require_relative "turbo/dom_id"
require_relative "turbo/request"
require_relative "turbo/response"
require_relative "turbo/action"
require_relative "turbo/stream_builder"
require_relative "turbo/helpers"
require_relative "turbo/part"
