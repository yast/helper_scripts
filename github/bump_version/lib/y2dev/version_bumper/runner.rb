require_relative "options"

module Y2Dev
  module VersionBumper
    class Runner
      def initialize(args)
        @args = args
      end

      def bump_version
        options

        nil
      end

      def options
        @options ||= Options.new(args).parse
      end

    private

      attr_reader :args

    end
  end
end
