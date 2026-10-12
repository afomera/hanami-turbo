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

      # Returns a `<turbo-stream>` element, like turbo-rails' helper of the same name.
      #
      # @see StreamBuilder#turbo_stream_action_tag
      #
      # @api public
      def turbo_stream_action_tag(...)
        turbo_stream.turbo_stream_action_tag(...)
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

      # Returns a form containing a single button, for actions that shouldn't be links (anything that
      # changes data). Like Rails' `button_to`.
      #
      # The form includes the CSRF token and, for methods other than GET and POST, a `_method` field.
      # Attributes are given to the button, so `data: {turbo_confirm: "..."}` asks Turbo to confirm
      # before submitting. Use `form:` for the form's own attributes.
      #
      # @example
      #   button_to "Delete", routes.path(:book, id: book.id), method: :delete,
      #     data: {turbo_confirm: "Delete #{book.title}?"}
      #
      #   button_to routes.path(:archive_book, id: book.id), form: {class: "inline"} do
      #     "<span>Archive</span>".html_safe
      #   end
      #
      # @param content [String, nil] button content (omit when giving a block)
      # @param url [String] the form's action
      # @param method [Symbol, String] HTTP method (default: POST)
      # @param form [Hash] attributes for the form (default class: `"button_to"`)
      # @param params [Hash] extra hidden fields to submit
      # @param attributes [Hash] attributes for the button
      #
      # @return [String] the form
      #
      # @api public
      def button_to(content = nil, url = nil, method: :post, form: {}, params: {}, **attributes, &block)
        if block
          raise ArgumentError, "give either content or a block, not both" if url

          url = content
          content = nil
        end
        raise ArgumentError, "a URL is required" unless url

        form_attributes = {class: "button_to", **form}

        # `values:` and `params:` are form_for's sources for field values; this form has no fields.
        form_for(url, method:, values: {}, params: {}, **form_attributes) do |f|
          hidden_fields = params.map { |name, value|
            tag.input(type: "hidden", name: name.to_s, value: value.to_s)
          }

          button =
            if block
              f.button(type: "submit", **attributes, &block)
            else
              f.button(content, type: "submit", **attributes)
            end

          (hidden_fields.join + button).html_safe
        end
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
