#!/usr/bin/env ruby

# This script creates a new label at Github which can be used for labeling
# issues and pull requests.
#
# For creating the hook you need a GitHub token with appropriate permissions,
# create your token at https://github.com/settings/tokens/new.
# Pass the token via "GH_TOKEN" environment variable.

# install missing gems
if !File.exist?("./vendor")
  puts "Installing needed Rubygems to ./vendor/bundle ..."
  `bundle install --path vendor/bundle`
end

require "rubygems"
require "bundler/setup"

require "octokit"

if !ENV["GH_TOKEN"]
  $stderr.puts "Error: The Github access token is not set."
  $stderr.puts "Pass it via the 'GH_TOKEN' environment variable."
  exit 1
end

github = Octokit::Client.new(access_token: ENV["GH_TOKEN"])

# We need to load the YaST repos in a loop, by default GitHub returns
# only the first 30 items (with per_page option it can be raised up to 100).
print "Reading YaST repositories at GitHub"
$stdout.flush
page = 1
git_repos = []
loop do
  print "."
  $stdout.flush
  repos = github.repos("yast", page: page)
  break if repos.empty?
  git_repos.concat(repos)
  page += 1
end

puts "\nFound #{git_repos.size} Git repositories"

# add a label for each repo
LABEL = "blog".freeze
COLOR = "fbca04".freeze

repo_names = git_repos.map { |git_repo| git_repo["name"] }

created = 0
repo_names.each do |repo|
  full_repo_name = "yast/#{repo}"
  labels = github.labels(full_repo_name).map { |h| h["name"] }

  if !labels.include?(LABEL)
    puts "Creating 'blog' label in repository: #{repo}"
    github.add_label(full_repo_name, LABEL, COLOR)
    created += 1
  else
    puts "Repository #{repo} already contains the label"
  end
end

puts "Created #{created} labels"
