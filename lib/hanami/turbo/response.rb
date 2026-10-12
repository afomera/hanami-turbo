# frozen_string_literal: true

module Hanami
  module Turbo
    # Turbo-aware rendering and redirects for `Hanami::Action::Response`.
    #
    # @api public
    module Response
      # Renders the view, choosing its format and layout for Turbo requests.
      #
      # - For Turbo Stream responses, renders the view's `.turbo_stream` template without a layout.
      #   If the view has no such template, switches the response to HTML and renders that instead,
      #   so Turbo never receives HTML labelled as a stream.
      # - For Turbo Frame requests, renders with {Turbo.config.frame_layout}, when one is set.
      #
      # Any `format:` or `layout:` given explicitly takes precedence.
      #
      # @api public
      def render(view, **input)
        options = _turbo_render_options(view, input)
        @_turbo_stream_rendered = (input[:format] || options[:format]) == FORMAT

        super(view, **options, **input)
      end

      # Redirects to the given URL, defaulting to `303 See Other` for non-GET requests.
      #
      # @see Turbo.config.see_other_redirects
      #
      # @api public
      def redirect_to(url, status: nil)
        status ||= SEE_OTHER if _turbo_see_other?

        status ? super(url, status:) : super(url)
      end

      # Returns true if the response is labelled a Turbo Stream but its body is not one.
      #
      # This happens for error responses that weren't rendered from a stream template, such as
      # `halt 404`. Turbo would treat these as empty streams and silently do nothing.
      #
      # @api private
      def turbo_stream_mismatch?
        return false unless format == FORMAT && status >= 400
        return false if @_turbo_stream_rendered

        # Only inspect buffered bodies; leave streamed ones (e.g. from `send_file`) alone.
        return false unless body.is_a?(Array)

        !body.first.to_s.lstrip.start_with?("<turbo-stream")
      end

      SEE_OTHER = 303
      private_constant :SEE_OTHER

      private

      def _turbo_render_options(view, input)
        options = {}

        if !input.key?(:format) && format == FORMAT
          return {format: FORMAT, layout: false} if ViewInternals.template?(view, FORMAT)

          # No stream template, so render HTML. Turbo handles HTML responses to form submissions
          # (including those made inside frames) like any other page.
          self.format = :html
        end

        if request&.turbo_frame? && !Turbo.config.frame_layout.nil? && input[:format] != FORMAT
          options[:layout] = Turbo.config.frame_layout
        end

        options
      end

      def _turbo_see_other?
        Turbo.config.see_other_redirects && request && !request.get? && !request.head?
      end
    end
  end
end

Hanami::Action::Response.prepend(Hanami::Turbo::Response)
