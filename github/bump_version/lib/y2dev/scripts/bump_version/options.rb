require "optparse"

module Y2Dev
  module Scripts
    class BumpVersion
      class Options

        attr_accessor :directory, :bug, :version, :branch

        def initialize(args)
          @args = args
          @parser = OptionParser.new

          define_options
        end

        def parse
          parser.parse!(args)
        rescue OptionParser::MissingArgument
          puts parser
        end

      private

        attr_reader :args

        attr_reader :parser

        def define_options
          banner
          bug_option
          version_option
          branch_option
          help
        end

        def banner
          parser.banner = "Usage: bump_version [options]"
        end

        def bug_option
          parser.on("--bug BUG", "Bug number to include in the changelog") do |bug|
            self.bug = bug
          end
        end

        def version_option
          parser.on("-v", "--version VERSION", "Version number to bump to") do |version|
            self.version = version
          end
        end

        def branch_option
          parser.on("--branch BRANCH", "Name of the new branch") do |branch|
            self.branch = branch
          end
        end

        def help
          parser.on_tail("-h", "--help", "Show this message") do
            puts parser
            exit
          end
        end
      end
    end
  end
end
