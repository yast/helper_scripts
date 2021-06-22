#!/usr/bin/env ruby

# This script creates labels at Github which can be used for labeling
# issues and pull requests.
#
# You need a GitHub token with appropriate permissions,
# create your token at https://github.com/settings/tokens/new.
# Pass the token via "GH_TOKEN" environment variable or via ~/.netrc file,
# see https://github.com/octokit/octokit.rb#authentication
#
# Links:
#  http://octokit.github.io/octokit.rb/Octokit/Client/Labels.html
#  https://docs.github.com/en/rest/reference/issues#create-a-label

# install missing gems
if !File.exist?(File.join(__dir__, "vendor"))
  puts "Installing needed Rubygems to ./vendor/bundle ..."
  `bundle install --path vendor/bundle`
end

require "rubygems"
require "bundler/setup"

require "octokit"
require "yaml"

# the GitHub organization, all repositories from this organization will be processed
GH_ORG = "yast".freeze

# use ~/.netrc ?
netrc = File.join(Dir.home, ".netrc")
client_options = if ENV["GH_TOKEN"]
  # Generate at https://github.com/settings/tokens
  { access_token: ENV["GH_TOKEN"] }
elsif File.exist?(netrc) && File.read(netrc).match(/^machine api.github.com/)
  { netrc: true }
else
  $stderr.puts "Error: The Github access token is not set."
  $stderr.puts "Pass it via the 'GH_TOKEN' environment variable"
  $stderr.puts "or write it to the ~/.netrc file."
  $stderr.puts "See https://github.com/octokit/octokit.rb#using-a-netrc-file"
  exit 1
end

github = Octokit::Client.new(client_options)
github.auto_paginate = true

puts "Reading #{GH_ORG.inspect} repositories at GitHub..."
git_repos = github.list_repositories(GH_ORG)
puts "Found #{git_repos.size} Git repositories\n\n"

labels = YAML.load_file(File.join(__dir__, ARGV[0] || "labels.yml"))

created = 0
git_repos.each do |repo|
  # archived repos are read-only and cannot be modified
  next if repo.archived
  repo_labels = github.labels(repo.full_name).map(&:name)

  labels.each do |label, data|
    # label already exists
    next if repo_labels.include?(label)

    puts "Creating label \"#{label}\" in repository #{repo.name}..."
    github.add_label(repo.full_name, label, data["color"], description: data["description"])
    created += 1
  end
end

puts "Created #{created} labels in total"
