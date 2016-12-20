#!/usr/bin/env ruby

# This script enables GitHub branch protection for all maintenance branches.
#
# For running it you need a GitHub token with appropriate permissions
# ("repo" access), create your token at https://github.com/settings/tokens/new.
# You need admin access rights for the repo to change the protection.
# Pass the token via "GH_TOKEN" environment variable.
# 
# --------------------------------------------------------------------
# Note: at the time of writing the Protected Branch API was available
# as a developer preview, i.e. it could have been changed since that.
# --------------------------------------------------------------------

# the GitHub organization, all organization repos will be processed
# if you want to touch only some of them then write some filtering code
GH_ORG = "yast"

# install missing gems
if !File.exist?("./.vendor")
  puts "Installing the needed Rubygems to ./.vendor/bundle ..."
  `bundle install --path .vendor/bundle`
end

require "rubygems"
require "bundler/setup"

require "octokit"

if !ENV["GH_TOKEN"]
  $stderr.puts "Error: The Github access token is not set."
  $stderr.puts "Pass it via the 'GH_TOKEN' environment variable."
  exit 1
end

github = Octokit::Client.new(:access_token => ENV["GH_TOKEN"])

# We need to load all repos in a loop, by default GitHub returns
# only the first 30 items (with per_page option it can be raised up to 100).
print "Reading #{GH_ORG.inspect} repositories at GitHub..."
$stdout.flush
page = 1
git_repos = []
begin
  print "."
  $stdout.flush
  repos = github.repos(GH_ORG, :page => page)
  git_repos.concat(repos)
  page += 1
end until repos.empty?

puts "\nFound #{git_repos.size} Git repositories"

# branches to protect, list of regexps - use as much specific regexp as possible
# to avoid matching branches like "SLE-12-SP1_bnc_966413" which is actualy
# a bugfix topic branch, not a maintenance one
TO_PROTECT = [
  # master
  /\Amaster\z/,
  # all openSUSE releases
  /\AopenSUSE-[0-9]+_[0-9]+\z/,
  # SLE10 GA
  /\ASLE10\z/,
  # SLE10 SPx
  /\ASLE10-SP[0-9]+\z/,
  # SLE11 GA
  /\ACode-11\z/,
  # SLE11 SPx
  /\ACode-11-SP[0-9]+\z/,
  # SLE12 GA
  /\ASLE-12-GA\z/,
  # SLE12 SPx
  /\ASLE-12-SP[0-9]+\z/,
  # CASP 1.0
  /\ASLE-12-SP2-CASP\z/
]

repo_names = git_repos.map{|git_repo| git_repo["name"]}

# options - require PR reviews also for the admins
options = {
  "required_pull_request_reviews" => {
    "include_admins" => true
  }
}

counter = 0
repo_names.each do |repo|
  full_repo_name = "#{GH_ORG}/#{repo}"
  branches = github.branches(full_repo_name)
  branches.each do |branch|
    if TO_PROTECT.any? {|r| branch["name"] =~ r}
      puts "#{full_repo_name}: protecting branch #{branch["name"]}..."
      github.protect_branch(full_repo_name, branch["name"], options)
      counter += 1
    end
  end
end

puts "Protection enabled for #{counter} branches in total."

