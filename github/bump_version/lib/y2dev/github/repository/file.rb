module Y2Dev
  class Github
    class Repository
      class File
        attr_reader :repository

        attr_reader :path

        attr_reader :data

        attr_reader :branch

        def initialize(repository, path)
          @repository = repository
          @path = path
          @branch = repository.branch
          @data = retrieve
        end

        def content
          encoded? ? decode_content : data.content
        end

      private

        def encoded?
          data.encoding == "base64"
        end

        def decode_content
          Base64.decode64(data.content)
        end

        def retrieve
          repository.github.client.contents(repository.full_name, path: path, ref: branch)
        end
      end
    end
  end
end