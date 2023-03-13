#!/usr/bin/env ruby
# frozen_string_literal: true

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
  system "bundle install --path .vendor/bundle"
end

require "rubygems"
require "bundler/setup"

require "octokit"
require "parallel"

# use ~/.netrc ?
netrc = File.join(Dir.home, ".netrc")
client_options = if ENV["GH_TOKEN"]
  # Generate at https://github.com/settings/tokens
  { access_token: ENV["GH_TOKEN"] }
elsif File.exist?(netrc) && File.read(netrc).match(/^machine api.github.com/)
  # see https://github.com/octokit/octokit.rb#authentication
  { netrc: true }
else
  warn "Error: The Github access token is not set."
  warn "Pass it via the 'GH_TOKEN' environment variable"
  warn "or write it to the ~/.netrc file."
  warn "See https://github.com/octokit/octokit.rb#using-a-netrc-file"
  exit 1
end

github = Octokit::Client.new(client_options)
github.auto_paginate = true

puts "Reading #{GH_ORG.inspect} repositories at GitHub..."
git_repos = github.list_repositories(GH_ORG)
puts "Found #{git_repos.size} Git repositories\n\n"

# branches to protect, list of regexps - use as much specific regexp as possible
# to avoid matching branches like "SLE-12-SP1_bnc_966413" which is actually
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
  # some repos use a different schema
  /\ASLE-10-SP[0-9]+\z/,
  # SLE11 GA
  /\ACode-11\z/,
  # SLE11 SPx
  /\ACode-11-SP[0-9]+\z/,
  # SLE12 GA
  /\ASLE-12-GA\z/,
  # SLE12 SPx
  /\ASLE-12-SP[0-9]+\z/,
  # SLE15 GA
  /\ASLE-15-GA\z/,
  # SLE12 SPx
  /\ASLE-15-SP[0-9]+\z/,
  # CASP 1.0
  /\ASLE-12-SP2-CASP\z/
].freeze

# skip these repositories
IGNORED_REPOS = [
  # SCRUM status (no pull requests)
  "burndown",
  # the translations are committed directly by Weblate (no pull requests)
  "yast-translations"
].freeze

repo_names = git_repos.map { |git_repo| git_repo["name"] }
# remove the ignored repos
repo_names -= IGNORED_REPOS

# options - require PR reviews also for the admins
options = {
  "enforce_admins"                => true,
  "required_pull_request_reviews" => {
    "include_admins" => true
  }
}

results = Parallel.map(repo_names) do |repo|
  full_repo_name = "#{GH_ORG}/#{repo}"
  puts "Checking #{full_repo_name} branches..."
  branches = github.branches(full_repo_name)
  branches.reduce(0) do |counter, branch|
    next counter if branch["protected"] || TO_PROTECT.none? { |r| branch["name"] =~ r }

    puts "  #{full_repo_name}: protecting branch #{branch["name"]}..."
    github.protect_branch(full_repo_name, branch["name"], options)
    counter + 1
  end
end

puts "Protection enabled for #{results.sum} branches in total."
