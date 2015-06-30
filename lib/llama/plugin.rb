module Llama
  module Plugin
    module ClassMethods
      attr_reader :matchers

      # @api private
      def self.extended(by)
        by.instance_exec do
          @matchers = {}
        end
      end

      def match(pattern, dest=:execute)
        pattern = Regexp.new("^#{pattern}$") if pattern.class == String
        @matchers[pattern] = dest
      end
    end

    # @api private
    def self.included(by)
      by.extend(ClassMethods)
    end
  end
end
