# frozen_string_literal: true

module Hanami
  module Turbo
    # Turbo-aware finishing for `Hanami::Action`.
    #
    # @api private
    module Action
      private

      # Sends error responses as HTML unless they really are Turbo Streams.
      #
      # A Turbo form submission negotiates the stream format before the action runs, so a `halt 404`
      # (or any other error response not rendered from a stream template) would otherwise go out as
      # a stream. Turbo would treat it as empty and do nothing. As HTML, Turbo shows it instead.
      #
      # This prepends `Action#finish`, which is private API, but is also how Hanami's own app
      # integration hooks into actions.
      def finish(request, response, halted)
        super.tap do
          response.format = :html if response.turbo_stream_mismatch?
        end
      end
    end
  end
end

Hanami::Action.prepend(Hanami::Turbo::Action)
