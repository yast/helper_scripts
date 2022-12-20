# frozen_string_literal: true

JENKINS_URL = "https://ci.opensuse.org"

def check_credentials
  return if ENV["JENKINS_USER"] && ENV["JENKINS_PASSWORD"]

  warn "Error: The jenkins credentials are not set."
  warn "Pass them via the 'JENKINS_USER' and 'JENKINS_PASSWORD' " \
       "environment variables."
  exit 1
end

def bundler_setup
  # install missing gems
  return if File.exist?("./.vendor")

  puts "Installing needed Rubygems to ./.vendor/bundle ..."
  system("bundle install --path .vendor/bundle")
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
