# frozen_string_literal: true

module Hanami
  module Turbo
    # View helpers for Turbo, included in the standard Hanami helpers (so available in templates,
    # scopes, and via `helpers` in parts).
    #
    # @api public
    module Helpers
      # Returns a builder for `<turbo-stream>` elements.
      #
      # @return [StreamBuilder]
      #
      # @see StreamBuilder
      #
      # @api public
      def turbo_stream
        StreamBuilder.new(self)
      end

      # Returns a `<turbo-frame>` element.
      #
      # The id may be a string, or a record (with an optional prefix), passed to {#dom_id}.
      #
      # @example
      #   turbo_frame_tag "tray" { "..." }
      #   turbo_frame_tag book                      # id="book_42"
      #   turbo_frame_tag book, :comments           # id="comments_book_42"
      #   turbo_frame_tag "details", src: "/books/1/details", loading: :lazy
      #
      # @api public
      def turbo_frame_tag(record_or_id, prefix = nil, src: nil, target: nil, loading: nil, **attributes, &block)
        id =
          if prefix.nil? && (record_or_id.is_a?(String) || record_or_id.is_a?(Symbol))
            record_or_id.to_s
          else
            dom_id(record_or_id, prefix)
          end

        tag.turbo_frame(id:, src:, target:, loading:, **attributes, &block)
      end

      # @see DomId.dom_id
      #
      # @api public
      def dom_id(record, prefix = nil)
        DomId.dom_id(record, prefix, inflector: _turbo_inflector)
      end

      # @see DomId.dom_class
      #
      # @api public
      def dom_class(record, prefix = nil)
        DomId.dom_class(record, prefix, inflector: _turbo_inflector)
      end

      private

      def _turbo_inflector
        respond_to?(:_inflector, true) ? _inflector : Turbo.inflector
      end
    end
  end
end

Hanami::View::Scope.include(Hanami::Turbo::Helpers)
Hanami::Extensions::View::StandardHelpers.include(Hanami::Turbo::Helpers)
