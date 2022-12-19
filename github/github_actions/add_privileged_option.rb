#!/usr/bin/env ruby
# frozen_string_literal: true

# This script adds the "--privileged" Docker option to the GitHub Actions
#
# You need admin access rights to temporarily disable the GitHub branch protection
# and allow direct push to "master".
#

# the GitHub organization
GH_ORG = "yast"

# install missing gems
if !File.exist?("./.vendor")
  puts "Installing the needed Rubygems to ./.vendor/bundle ..."
  system "bundle install --path .vendor/bundle"
end

require "rubygems"
require "bundler/setup"

require "octokit"

# optionally confirm the changes
CONFIRM = ENV["CONFIRM"] == "1"

# subdirectory where to clone Git repositories
GIT_CHECKOUT_DIR = "github"

def workflow_files
  Dir.glob(".github/workflows/*.yml") + Dir.glob(".github/workflows/*.yaml")
end

def add_privileged_option(file)
  # unfortunately we cannot use "YAML.load_file" here as it would remove the comments :-(
  content = File.read(file)

  new_content = content.gsub(/^(\s*)container:\s*(\S+)$/,
    "\\1container:\n\\1  image: \\2\n\\1  options: --privileged")
  changed = new_content != content

  File.write(file, new_content) if changed

  changed
end

# create the octokit client
def create_client
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

  client = Octokit::Client.new(client_options)
  client.auto_paginate = true

  client
end

# ask user to confirm the changes before git push
def confirmed?
  msg = "\nCommit the change? [Y/n] "
  print msg

  input = nil
  loop do
    input = $stdin.gets.strip
    break if ["Y", "y", "N", "n", ""].include?(input)

    print "Invalid input#{msg}"
  end

  # assume approval by default, just pressing [Enter] (empty string) is enough
  ["Y", "y", ""].include?(input)
end

github = create_client

puts "Reading #{GH_ORG.inspect} repositories at GitHub..."
git_repos = github.list_repositories(GH_ORG)
puts "Found #{git_repos.size} Git repositories\n\n"

# GitHub branch protection options - require PR reviews also for the admins
# https://octokit.github.io/octokit.rb/Octokit/Client/Repositories.html#protect_branch-instance_method
# https://docs.github.com/en/rest/reference/repos#update-branch-protection
options = {
  "enforce_admins"                => true,
  "required_pull_request_reviews" => {
    "require_code_owner_reviews" => true,
    "include_admins"             => true
  }
}

git_repos.each do |repo|
  # where to checkout the Git repository
  checkout_dir = File.join(GIT_CHECKOUT_DIR, repo.name)

  # already cloned?
  if !File.directory?(checkout_dir)
    puts
    # we do not need the complete history, use depth=1
    system("git clone --depth 1 #{repo.ssh_url} #{checkout_dir}")
  end

  Dir.chdir(checkout_dir) do
    # no change or dry run
    next if workflow_files.map { |f| add_privileged_option(f) }.none?

    puts "Updating GitHub Actions:"
    system("git --no-pager diff")

    next if CONFIRM && !confirmed?

    system("git commit -a -m \"GitHub Actions workaround: use --privileged option\"")
    github.unprotect_branch(repo.full_name, "master")
    system("git push")
    github.protect_branch(repo.full_name, "master", options)
  end
end
