# frozen_string_literal: true

module Hanami
  module Turbo
    # The only place hanami-turbo reaches into hanami-view's private API.
    #
    # hanami-view has no public way to ask whether a template exists, or to render with a different
    # format partway through a render. Keeping these calls together makes them easy to audit, and
    # to replace if hanami-view gains public equivalents.
    #
    # @api private
    module ViewInternals
      module_function

      # Returns true if the view has a template for the format.
      def template?(view, format)
        !view.rendering(format: format).renderer.send(:lookup, view.config.template, format).nil?
      end

      # Returns true if the rendering can find the partial in the format.
      def partial?(rendering, name, format)
        renderer = rendering.renderer
        !renderer.send(:lookup, renderer.send(:name_for_partial, name), format).nil?
      end

      # Returns a copy of the rendering using a different format, sharing its config and context.
      def with_format(rendering, format, context)
        Hanami::View::Rendering.new(
          config_data: rendering.renderer.send(:config_data),
          format: format,
          context: context
        )
      end
    end
  end
end
