# require "y2dev/github/repository"

module Y2Dev
  class VersionBumper
    attr_accessor :version_number

    attr_accessor :branch_name

    attr_accessor :bug_number

    attr_accessor :repository

    def initialize
      yield(self)
    end

    def bump_version
      update_repository
      create_pull_request
    end

  private

    def update_repository
      update_spec_file
      update_changes_file

      create_branch
      create_commit
    end

    def update_spec_file
      content = repository.content(spec_file)

      content = modify_version_number(content)

      repository.update_content(spec_file, content)
    end

    def update_changes_file
      content = repository.content(changes_file)

      content = add_changelog(content)

      repository.update_content(changes_file, content)
    end

    def modify_version_number(content)
      # TODO
      content + "\n# testing\n"
    end

    def add_changelog(content)
      # TODO
      content + "\n# testing\n"
    end

    def create_branch
      repository.create_branch(branch_name)
    end

    COMMIT_MESSAGE = "Update version and changelog".freeze

    def create_commit
      repository.create_commit(COMMIT_MESSAGE)
    end

    def create_pull_request
      repository.create_pull_request("master", branch_name, pull_request_title, pull_request_body)
    end

    def pull_request_title
      ""
    end

    def pull_request_body
      ""
    end

    def spec_file
      repository.file("package/*.spec")
    end

    def changes_files
      repository.file("package/*.changes")
    end
  end
end
