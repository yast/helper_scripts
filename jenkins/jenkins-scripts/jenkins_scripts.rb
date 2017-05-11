
JENKINS_URL = "https://ci.opensuse.org".freeze

def check_credentials
  if !ENV["JENKINS_USER"] || !ENV["JENKINS_PASSWORD"]
    $stderr.puts "Error: The jenkins credentials are not set."
    $stderr.puts "Pass them via the 'JENKINS_USER' and 'JENKINS_PASSWORD' " \
      "environment variables."
    exit 1
  end
end

def bundler_setup
  # install missing gems
  if !File.exist?("./.vendor")
    puts "Installing needed Rubygems to ./.vendor/bundle ..."
    system("bundle install --path .vendor/bundle")
  end
end

def require_all
  require "rubygems"
  require "bundler/setup"

  require "jenkins_api_client"
  require "logger"
end

def jenkins_setup
  check_credentials
  bundler_setup
  require_all
end

def jenkins_client
  JenkinsApi::Client.new(server_url: JENKINS_URL, log_location: "jenkins.log",
    username: ENV["JENKINS_USER"], password: ENV["JENKINS_PASSWORD"])
end

def all_jobs(client)
  client.job.list_all
end
