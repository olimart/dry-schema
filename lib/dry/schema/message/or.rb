# frozen_string_literal: true

require 'dry/equalizer'

module Dry
  module Schema
    # Message objects used by message sets
    #
    # @api public
    class Message
      # A message sub-type used by OR operations
      #
      # @api public
      module Or
        # @api private
        def self.[](left, right, messages)
          msgs = [left, right].flatten
          paths = msgs.map(&:path)

          if paths.uniq.size == 1
            SinglePath.new(left, right, messages)
          elsif right.is_a?(Array)
            if left.is_a?(Array) && paths.uniq.size > 1
              Or::MultiPath.new(left, right)
            else
              right
            end
          else
            msgs.max
          end
        end

        # @api private
        class Abstract
          # @api private
          attr_reader :left

          # @api private
          attr_reader :right

          # @api private
          def initialize(left, right, *)
            @left = left
            @right = right
          end
        end

        # @api public
        class SinglePath < Abstract
          # @api private
          attr_reader :path

          # @api private
          attr_reader :_path

          # @api private
          attr_reader :messages

          # @api private
          def initialize(*args, messages)
            super(*args)
            @messages = messages
            @path = left.path
            @_path = left._path
          end

          # Dump a message into a string
          #
          # Both sides of the message will be joined using translated
          # value under `dry_schema.or` message key
          #
          # @see Message#dump
          #
          # @return [String]
          #
          # @api public
          def dump
            "#{left.dump} #{messages[:or][:text]} #{right.dump}"
          end
          alias_method :to_s, :dump

          # Dump an `or` message into a hash
          #
          # @see Message#to_h
          #
          # @return [String]
          #
          # @api public
          def to_h
            _path.to_h(dump)
          end

          # @api private
          def to_a
            [left, right]
          end
        end

        # @api public
        class MultiPath < Abstract
          # @api private
          attr_reader :root

          # @api private
          def initialize(*args)
            super
            @root = [left, right].flatten.map(&:path).reduce(:&)
            @left = left.map { |msg| msg.to_or(root) }
            @right = right.map { |msg| msg.to_or(root) }
          end

          # @api public
          def to_h
            Path[[*root, :or]].to_h([merge(left.map(&:to_h)), merge(right.map(&:to_h))])
          end

          private

          # @api private
          def merge(messages)
            messages.reduce(EMPTY_HASH.dup) { |a, e| deep_merge(a, e) }
          end

          # @api private
          def deep_merge(h1, h2, &block)
            h1.merge(h2) do |_, val1, val2|
              if val1.is_a?(Hash) && val2.is_a?(Hash)
                deep_merge(val1, val2, &block)
              elsif val1.is_a?(Array) && val2.is_a?(Array)
                val1 + val2
              else
                [val1, val2]
              end
            end
          end
        end
      end
    end
  end
end
