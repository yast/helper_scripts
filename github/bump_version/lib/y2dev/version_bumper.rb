require "y2dev/version_bumper/options"
require "y2dev/github/repository"

module Y2Dev
  class VersionBumper
    def initialize(args)
      @args = args
    end

    def bump_version
      options

      repositories.each do |repository|
        bump_repository(repository)
      end

      nil
    end

  private

    attr_reader :args

    def options
      @options ||= parse_options
    end

    def repositories
      @repositories ||= read_repositories
    end

    def parse_options
      Options.new(args).parse
    end

    def read_repositories
      GitHub::Repository.all(options.directory)
    end

    COMMIT_MESSAGE = "Update version and changelog".freeze

    def bump_repository(repository)
      repository.new_branch(options.branch)

      update_spec(repository)
      update_chagelog(repository)

      repository.commit(COMMIT_MESSAGE)
      repository.push

      pull_request(repository)
    end

    def update_spec(repository)
      spec_file = repository.file("package/*.spec")
    end

    def update_chagelog(repository)

    end

    def pull_request(repository)

    end
  end
end
