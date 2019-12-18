#! /usr/bin/env ruby

# This is a helper script which enables/disables all YaST Jenkins jobs.
# It is run from a separate job.
# 
# Example usage:
#
#   JENKINS_TOKEN=... ./jenkins_autosubmission.rb --enable --url https://ci.suse.de/view/YaST/
#

require "json"
require "net/http"
require "open-uri"
require "optparse"
require "optparse/uri"
require "uri"

class CommandLineError < RuntimeError
end

# command line options
class CommandLineOptions
  attr_accessor :url, :enable, :branch

  def initialize
    # the default branch
    @branch = "master"
  end
  
  def self.parse
    options = self.new
    
    OptionParser.new do |parser|
      parser.on("-u", "--url [URL]", URI, "URL of the Jenkins server (should include a view)") do |u|
        options.url = u
      end
      
      parser.on("-b", "--branch BRANCH", "Branch name (default: \"master\")") do |b|
        options.branch = b
      end
      
      parser.on("-e", "--enable", "Enable the jobs") do
        options.enable = true
      end
      
      parser.on("-d", "--disable", "Disable the jobs") do
        options.enable = false
      end
    end.parse!
    
    options
  end

  def validate!
    raise CommandLineError, "The Jenkins URL is not set correctly!" if url.nil?
    raise CommandLineError, "Missing --enable or --disable option!" if enable.nil?
    raise CommandLineError, "Invalid branch name!" if branch.nil? || branch.empty?
  end
end

class JenkinsJob
  attr_reader :url, :name, :status

  def initialize(url, name, status)
    @url = url
    @name = name
    @status = status
  end

  def enabled?
    status != "disabled"
  end

  def self.find(url, branch)
    query_url = url.dup
    query_url.path = File.join(query_url.path, "api/json")
    jobs = JSON.parse(query_url.read)["jobs"]
  
    jobs.each_with_object([]) do |j, arr|
      if j["name"].match(/\Ayast-.*-#{Regexp.escape(branch)}\z/) &&
        !j["name"].match(/\Ayast-ci-/)

        arr << self.new(URI(j["url"]), j["name"], j["color"])
      end
    end
  end

  def change(enable)
    puts "#{enable ? "Enabling" : "Disabling"} #{name}..."

    uri = url.dup
    uri.path = File.join(uri.path, (enable ? "enable" : "disable"))
  
    # unfortunately for POST requests we cannot use "open-uri", use "net/http"
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.is_a?(URI::HTTPS)
  
    request = Net::HTTP::Post.new(uri.request_uri)
    # get the token from https://ci.suse.de/user/yast/configure
    # or https://ci.opensuse.org/user/yast/configure
    request.basic_auth("yast", ENV["JENKINS_TOKEN"])
  
    response = http.request(request)
    success = response.is_a?(Net::HTTPFound)

    $stderr.puts "ERROR: Changing job #{name} failed!" unless success
    
    success
  end
end

begin
  opts = CommandLineOptions.parse
  opts.validate!

  jobs = JenkinsJob.find(opts.url, opts.branch)
  # remove jobs which do not need to be changed
  jobs.reject!{|j| opts.enable == j.enabled?}
  puts "Updating #{jobs.size} jobs..."

  ret = jobs.map{|j| j.change(opts.enable)}.all? ? 0 : 1
  puts "Done"
  exit ret
rescue CommandLineError, OptionParser::InvalidOption => e
  $stderr.puts "ERROR: #{e.message}"
  exit 1
rescue => e
  $stderr.puts "ERROR: #{e.message} #{e.backtrace}"
  exit 1
end
