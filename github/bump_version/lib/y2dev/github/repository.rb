module Y2Dev
  class Github
    class Repository
      attr_reader :client

      attr_reader :data

      def initialize(client, data)
        @client = client
        @data = data
      end

      def file(pattern)

      end

      def content(file)

      end

      def update_content(file, new_content)

      end

      def create_branch(branch_name)
      end

      def create_commit(message)
      end

      def create_pull_request(base, head, title, body)
      end
    end
  end
end