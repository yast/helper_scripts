#!/usr/bin/env ruby

# This script triggers the YaST job builds for the master branch at 
# the publis Jenkins.
#
# Pass the Jenkins credentials via "JENKINS_USER" and "JENKINS_PASSWORD"
# environment variables.

if !ENV["JENKINS_USER"] || !ENV["JENKINS_PASSWORD"]
  $stderr.puts "Error: The jenkins credentials are not set."
  $stderr.puts "Pass them via the 'JENKINS_USER' and 'JENKINS_PASSWORD' " \
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
jenkins_jobs = jenkins.job.list_all.select { |j| j.match(/^yast|^libyui/) && j.end_with?("-master")}
puts "Found #{jenkins_jobs.size} Jenkins jobs"

jenkins_jobs.each_with_index do |job, index|
  # wait until the YaST queue is empty
  while !jenkins.queue.list.select { |j| j.match(/^yast|^libyui/) }.empty? do
    puts "Some job already queued, sleeping for a while... "
    sleep(30)
  end

  puts "[#{index}/#{jenkins_jobs.size}] Starting job #{job}..."
  jenkins.job.build(job)
  sleep(30)
end
