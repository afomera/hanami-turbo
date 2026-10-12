# frozen_string_literal: true

module Hanami
  module Turbo
    # DOM id methods for view parts.
    #
    # @example
    #   <article id="<%= book.dom_id %>">
    #
    # @api public
    module Part
      # @see DomId.dom_id
      #
      # @api public
      def dom_id(prefix = nil)
        DomId.dom_id(self, prefix, inflector: _rendering.inflector)
      end

      # @see DomId.dom_class
      #
      # @api public
      def dom_class(prefix = nil)
        DomId.dom_class(self, prefix, inflector: _rendering.inflector)
      end
    end
  end
end

Hanami::View::Part.include(Hanami::Turbo::Part)
