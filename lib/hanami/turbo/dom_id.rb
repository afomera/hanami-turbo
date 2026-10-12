# frozen_string_literal: true

module Hanami
  module Turbo
    # Builds DOM ids and classes for records, for use as Turbo Frame ids and Turbo Stream targets.
    #
    # Records may be view parts (their value is used) or any object responding to `#id`. The name
    # comes from the record's class, so a `Bookshelf::Structs::Book` with id 42 has the DOM id
    # `"book_42"`.
    #
    # @api public
    module DomId
      NEW = "new"
      JOIN = "_"

      module_function

      # Returns the DOM id for a record.
      #
      # @example
      #   dom_id(book)              # => "book_42"
      #   dom_id(book, :comments)   # => "comments_book_42"
      #   dom_id(Book.new)          # => "new_book"
      #   dom_id(Book.new, :edit)   # => "edit_book"
      #   dom_id("custom_target")   # => "custom_target"
      #
      # @param record [Object, String, Symbol] the record, or a ready-made id
      # @param prefix [String, Symbol, nil] optional prefix
      #
      # @return [String]
      #
      # @api public
      def dom_id(record, prefix = nil, inflector: Turbo.inflector)
        return record.to_s if record.is_a?(String) || record.is_a?(Symbol)

        value = unwrap(record)
        id = value.id if value.respond_to?(:id)

        if id.nil?
          dom_class(record, prefix || NEW, inflector:)
        else
          [dom_class(record, prefix, inflector:), id].join(JOIN)
        end
      end

      # Returns the DOM class for a record (its singular name, with an optional prefix).
      #
      # @param record [Object] the record
      # @param prefix [String, Symbol, nil] optional prefix
      #
      # @return [String]
      #
      # @api public
      def dom_class(record, prefix = nil, inflector: Turbo.inflector)
        name = record_name(record, inflector)
        prefix ? [prefix, name].join(JOIN) : name
      end

      # @api private
      def record_name(record, inflector)
        value = unwrap(record)
        klass = value.is_a?(Class) ? value : value.class

        # Anonymous classes (and plain hashes or structs from ad hoc data) have no useful class name,
        # so fall back to the part's name, when there is one.
        if klass.name.nil? || [Hash, Struct, Data, Object].include?(klass)
          return inflector.singularize(record._name.to_s) if record.respond_to?(:_name)

          raise ArgumentError, "cannot infer a DOM id name for #{value.inspect}"
        end

        inflector.underscore(inflector.demodulize(klass.name))
      end

      # @api private
      def unwrap(record)
        record.is_a?(Hanami::View::Part) ? record._value : record
      end
    end
  end
end
