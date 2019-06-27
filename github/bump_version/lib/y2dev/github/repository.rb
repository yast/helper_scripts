require "base64"
require "y2dev/github/repository/file"

module Y2Dev
  class Github
    class Repository
      attr_reader :github

      attr_reader :data

      attr_accessor :branch

      def initialize(github, data)
        @github = github
        @data = data
        @branch = "master"
        @files = []
      end

      def name
        data.name
      end

      def full_name
        data.full_name
      end

      def file(glob)
        find_file(glob) || retrieve_file(glob)
      end

      def update_content(file, new_content)

      end

      def create_branch(branch_name)
      end

      def create_commit(message)
      end

      def create_pull_request(base, head, title, body)
      end

    private

      attr_reader :files

      def find_file(path)
        files.find { |f| f.path == path && f.branch == branch }
      end

      def retrieve_file(glob)
        path = find_path(glob)

        return nil unless path

        find_file(path) || add_file(path)
      end

      def add_file(path)
        file = Repository::File.new(self, path)
        files << file

        file
      end

      def find_path(glob)
        paths = directory_paths(::File.dirname(glob))

        paths.find { |f| ::File.fnmatch(glob, f) }
      end

      def directory_paths(directory)
        github.client.contents(full_name, ref: branch, path: directory).map(&:path)
      end
    end
  end
end