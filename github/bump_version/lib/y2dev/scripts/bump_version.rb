require "y2dev/scripts/bump_version/options"
require "y2dev/version_bumper"

module Y2Dev
  module Scripts
    class BumpVersion
      def self.run(args)
        new(args).run
      end

      def initialize(args)
        @args = args
      end

      def run
        repositories.each { |r| bump_version(r) }
      end

    private

      attr_reader :args

      def options
        @options ||= parse_options
      end

      def parse_options
        options = Options.new(args)
        options.parse

        options
      end

      def repositories
        Github::Repository.all
      end

      def bump_version(repository)
        bumper.repository = repository
        bumper.bump_version
      end

      def bumper
        @bumper ||= VersionBumper.new do |config|
          config.version_number = options.version
          config.bug_number = options.bug
          config.branch_name = options.branch
        end
      end
    end
  end
end
