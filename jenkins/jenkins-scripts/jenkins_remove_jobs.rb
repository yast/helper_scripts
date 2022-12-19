#!/usr/bin/env ruby
# frozen_string_literal: true

# This script triggers the YaST job builds for the master branch at
# the publis Jenkins.
#
# Pass the Jenkins credentials via "JENKINS_USER" and "JENKINS_PASSWORD"
# environment variables.

if !ENV["JENKINS_USER"] || !ENV["JENKINS_PASSWORD"]
  warn "Error: The jenkins credentials are not set."
  warn "Pass them via the 'JENKINS_USER' and 'JENKINS_PASSWORD' " \
       "environment variables."
  exit 1
end

# install missing gems
if !File.exist?("./.vendor")
  puts "Installing needed Rubygems to ./.vendor/bundle ..."
  system("bundle install --path .vendor/bundle")
end

require "rubygems"
require "bundler/setup"

require "jenkins_api_client"
require "logger"

JENKINS_URL = "https://ci.opensuse.org"

puts "Reading Jenkins jobs from #{JENKINS_URL}..."
jenkins = JenkinsApi::Client.new(server_url: JENKINS_URL, log_location: "jenkins.log",
  username: ENV["JENKINS_USER"], password: ENV["JENKINS_PASSWORD"])

# get only the master branch YaST jobs
jenkins_jobs = jenkins.job.list_all.select do |j|
  j.match(/^yast|^libyui/) && j.end_with?("-github-push")
end
puts "Found #{jenkins_jobs.size} Jenkins jobs"
puts jenkins_jobs

jenkins_jobs.each_with_index do |job, index|
  puts "[#{index}] removing #{job}"
  jenkins.job.delete(job)
end
