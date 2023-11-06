#!/usr/bin/env ruby
# frozen_string_literal: true

# This script updates GitHub Action to only run against Tumbleweed.
# The SLE/Leap in only supported in the SLE* branches, master is Tumbleweed only.
#
# You need admin access rights to temporarily disable the GitHub branch protection
# and allow direct push to "master".
#

# install missing gems
if !File.exist?("./.vendor")
  puts "Installing the required Rubygems to ./.vendor/bundle ..."
  system "bundle install --path .vendor/bundle"
end

# install missing gems
if !File.exist?("./node_modules")
  puts "Installing the required NPM packages..."
  system "npm ci"
end

require "rubygems"
require "bundler/setup"
require "shellwords"

require "octokit"
require "byebug"
require_relative "../github_actions/gh_helpers"

# subdirectory where to clone Git repositories
GIT_CHECKOUT_DIR = "github"

# octokit GitHub client
github = gh_client
# all YaST repositories
git_repos = gh_repos(github, "yast")

# counter
fixed = 0

git_repos.each do |repo|
  # where to checkout the Git repository
  checkout_dir = File.join(GIT_CHECKOUT_DIR, repo.name)

  if !File.directory?(checkout_dir)
    system("git clone --depth 1 #{repo.ssh_url.shellescape} #{checkout_dir.shellescape}")
  end

  # process all .yml and .yaml files there
  Dir[File.join(checkout_dir, ".github/workflows/*.y{a,}ml")].each do |f|
    # use a Javascript tool because the YAML parser there can keep the comments
    # in the file
    system("./remove_leap.js #{f.shellescape}")
  end

  Dir.chdir(checkout_dir) do
    # commit and push only if there is a change
    if !`git diff`.empty?
      puts "Updating #{repo.name} ..."
      with_unprotected(github, repo.full_name, repo.default_branch) do
        system("git commit -a -m \"Fixed CI - build only against Tumbleweed\"")
        system("git push")
      end

      fixed += 1
    end
  end
end

puts "Fixed repositories: #{fixed}"
