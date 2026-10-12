# frozen_string_literal: true

module Hanami
  module Turbo
    # Turbo-specific methods for `Hanami::Action::Request`.
    #
    # @api public
    module Request
      TURBO_FRAME_HEADER = "HTTP_TURBO_FRAME"
      ACCEPT_HEADER = "HTTP_ACCEPT"

      # Returns the id of the Turbo Frame that made this request, if any.
      #
      # @return [String, nil]
      #
      # @api public
      def turbo_frame
        get_header(TURBO_FRAME_HEADER)
      end

      # Returns true if this request was made by a Turbo Frame.
      #
      # @return [Boolean]
      #
      # @api public
      def turbo_frame?
        !turbo_frame.nil?
      end

      # Returns true if the request explicitly accepts Turbo Stream responses.
      #
      # Turbo adds the stream media type to the `Accept` header of form submissions. Unlike
      # `#accept?`, this does not match wildcard `Accept` headers.
      #
      # @return [Boolean]
      #
      # @api public
      def turbo_stream?
        get_header(ACCEPT_HEADER).to_s.include?(MEDIA_TYPE)
      end
    end
  end
end

Hanami::Action::Request.include(Hanami::Turbo::Request)
