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
    # Add your own stream actions by including a module, as turbo-rails apps do with
    # `Turbo::Streams::TagBuilder`. Methods can call {#action}, {#action_all}, or
    # {#turbo_stream_action_tag}, so modules written for turbo-rails work unchanged:
    #
    #   module MyApp::TurboStreamActions
    #     def toast(message, level: "info")
    #       action(:toast, nil, message:, level:)
    #     end
    #   end
    #
    #   Hanami::Turbo::StreamBuilder.include(MyApp::TurboStreamActions)
    #
    # Then handle the action in JavaScript via `Turbo.StreamActions`.
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
      # Any other keyword arguments become attributes of the `<turbo-stream>` element (except
      # `partial:`, `locals:` and `method:`, which are used as described below). A `<template>` is
      # included when there is content, and always for Turbo's built-in content actions.
      #
      # @param name [Symbol, String] the stream action
      # @param target [Object, nil] DOM id string, a record, or nil for actions without a target
      # @param content [String, nil] content for the element's `<template>`
      # @param partial [String, nil] partial to render as the content
      # @param locals [Hash] locals for the partial
      # @param method [Symbol, nil] `:morph` to morph rather than replace (for `replace` and `update`)
      #
      # @api public
      def action(name, target, content = nil, **options, &block)
        target_attributes = target.nil? ? {} : {target: DomId.dom_id(target, inflector: inflector)}
        stream(name, target_attributes, content, **options, &block)
      end

      # Builds a stream element for any action, targeting all elements matching a CSS selector.
      #
      # @api public
      def action_all(name, targets, content = nil, **options, &block)
        stream(name, {targets: targets}, content, **options, &block)
      end

      # Builds a stream element, with the same signature as turbo-rails' `turbo_stream_action_tag`.
      #
      # @example
      #   turbo_stream_action_tag :console_log, message: "Hello"
      #   turbo_stream_action_tag :notify, target: book, template: "<b>Saved</b>".html_safe
      #
      # @param name [Symbol, String] the stream action
      # @param target [Object, nil] DOM id string or record
      # @param targets [String, nil] CSS selector, instead of a target
      # @param template [String, nil] content for the element's `<template>`
      # @param attributes [Hash] other attributes for the `<turbo-stream>` element
      #
      # @api public
      def turbo_stream_action_tag(name, target: nil, targets: nil, template: nil, **attributes)
        if targets
          action_all(name, targets, template, **attributes)
        else
          action(name, target, template, **attributes)
        end
      end

      private

      attr_reader :scope

      def stream(name, target_attributes, content = nil, partial: nil, locals: {}, method: nil, **attributes, &block)
        content = render_partial(partial, locals) if partial
        content = block.call if block

        if name.to_sym != :remove && (!content.nil? || CONTENT_ACTIONS.include?(name.to_sym))
          template = scope.tag.template(content.to_s)
        end

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
