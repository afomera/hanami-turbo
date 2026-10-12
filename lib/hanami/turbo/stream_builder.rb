# frozen_string_literal: true

module Hanami
  module Turbo
    # Builds `<turbo-stream>` elements. Returned by the `turbo_stream` view helper.
    #
    # Each action takes a target (a DOM id string, or a record passed through {DomId.dom_id}), and
    # its content as a string, a block, or a partial to render.
    #
    # Partials are rendered in the current format when such a partial exists (e.g.
    # `_book.turbo_stream.erb`), and otherwise as HTML, so the same `_book.html.erb` partial can be
    # used for full page renders and for streams.
    #
    # @example In a `.turbo_stream.erb` template
    #   <%= turbo_stream.append "books", partial: "books/book", locals: {book:} %>
    #   <%= turbo_stream.replace book do %>
    #     <p><%= book.title %></p>
    #   <% end %>
    #   <%= turbo_stream.remove book %>
    #
    # @api public
    class StreamBuilder
      # Actions that take content.
      CONTENT_ACTIONS = %i[append prepend replace update before after].freeze

      # @api private
      def initialize(scope)
        @scope = scope
      end

      CONTENT_ACTIONS.each do |name|
        # Targets one element by DOM id.
        define_method(name) do |target, content = nil, **options, &block|
          action(name, target, content, **options, &block)
        end

        # Targets all elements matching a CSS selector.
        define_method(:"#{name}_all") do |targets, content = nil, **options, &block|
          action_all(name, targets, content, **options, &block)
        end
      end

      # Removes the target element.
      #
      # @api public
      def remove(target)
        action(:remove, target)
      end

      # Removes all elements matching the CSS selector.
      #
      # @api public
      def remove_all(targets)
        action_all(:remove, targets)
      end

      # Asks the page to refresh itself (Turbo 8 page refreshes).
      #
      # @param request_id [String, nil] identifies the request, so the page that made it can ignore
      #   the refresh
      #
      # @api public
      def refresh(request_id: nil, **attributes)
        stream_tag(action: :refresh, "request-id": request_id, **attributes)
      end

      # Builds a stream element for any action, including custom ones.
      #
      # @param name [Symbol, String] the stream action
      # @param target [Object] DOM id string, or a record
      # @param content [String, nil] content for the element's `<template>`
      # @param partial [String, nil] partial to render as the content
      # @param locals [Hash] locals for the partial
      # @param method [Symbol, nil] `:morph` to morph rather than replace (for `replace` and `update`)
      #
      # @api public
      def action(name, target, content = nil, **options, &block)
        stream(name, {target: DomId.dom_id(target, inflector: inflector)}, content, **options, &block)
      end

      # Builds a stream element for any action, targeting all elements matching a CSS selector.
      #
      # @api public
      def action_all(name, targets, content = nil, **options, &block)
        stream(name, {targets: targets}, content, **options, &block)
      end

      private

      attr_reader :scope

      def stream(name, target_attributes, content = nil, partial: nil, locals: {}, method: nil, **attributes, &block)
        content = render_partial(partial, locals) if partial
        content = block.call if block

        template = scope.tag.template(content.to_s) unless name == :remove

        stream_tag(template, action: name, **target_attributes, method:, **attributes)
      end

      def render_partial(name, locals)
        rendering = scope._rendering
        format = rendering.format

        if format == :html || ViewInternals.partial?(rendering, name, format)
          return scope.render(name, **locals)
        end

        html_rendering = ViewInternals.with_format(rendering, :html, scope._context)
        partial_locals = locals.empty? ? scope._locals : locals
        html_rendering.partial(name, scope.class.new(locals: partial_locals, rendering: html_rendering))
      end

      def stream_tag(content = nil, **attributes)
        scope.tag.turbo_stream(content.to_s.html_safe, **attributes.compact)
      end

      def inflector
        scope.respond_to?(:_inflector, true) ? scope.send(:_inflector) : Turbo.inflector
      end
    end
  end
end
