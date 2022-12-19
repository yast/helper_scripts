#!/usr/bin/env ruby
# frozen_string_literal: true

# This script bumps the version in all YaST packages
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

############# start of editable values ############

# new package version
NEW_PACKAGE_VERSION = "4.4.0"
# some packages use distro based version
NEW_DISTRO_VERSION = "15.4.0"
# author + email, written into the changes files
AUTHOR = "Ladislav Slezák <lslezak@suse.cz>"
# change only packages which have this branch defined
GIT_BRANCH = "SLE-15-SP3"
# bug number used in changes
BUG_NR = "1185510"

############# end of editable values ############

# do not change the
DRY_RUN = ENV["DRY_RUN"]

# for checking whether the version has been already bumped
NEW_PACKAGE_PREFIX = NEW_PACKAGE_VERSION[0..-2]
# prefix of the distro version
NEW_DISTRO_PREFIX = NEW_DISTRO_VERSION[0..-2].freeze

# the major version prefix of the package version
NEW_MAJOR_PACKAGE_VERSION = NEW_PACKAGE_VERSION.split(".").first + "."
# the major version prefix of the distro version
NEW_MAJOR_DISTRO_VERSION = NEW_DISTRO_VERSION.split(".").first + "."

# subdirectory where to clone Git repositories
GIT_CHECKOUT_DIR = "github"

# skip these repositories
EXCLUDE_REPOS = [
  # this is a Ruby gem, not an YaST module
  "yast-rake",
  # these are bound to the SUSE Manager version, not the SLE version
  "skelcd-control-suse-manager-proxy",
  "skelcd-control-suse-manager-server"
].freeze

# these repositories are openSUSE Leap only (not in SLE)
EXTRA_REPOS = [
  "yast-alternatives",
  "yast-docker",
  "yast-slp-server"
].freeze

def spec_files
  Dir.glob("package/*.spec")
end

# read the package version from the spec file(s)
def read_version
  spec_files.map do |spec_file|
    spec = File.read(spec_file)
    spec.match(/^\s*Version:\s*(\S+)$/)[1]
  end
end

# set the new version in the spec files(s)
def update_version(version)
  spec_files.each do |spec_file|
    spec = File.read(spec_file)
    spec.gsub!(/^(\s*)Version:(\s*).*$/, "\\1Version:\\2#{version}")
    File.write(spec_file, spec)
  end
end

TIME_ENTRY = Time.now.utc.strftime("%a %b %d %T UTC %Y")

def update_changes(version)
  entry = <<~ENTRY
    -------------------------------------------------------------------
    #{TIME_ENTRY} - #{AUTHOR}

    - #{version} (#bsc#{BUG_NR})

  ENTRY

  Dir.glob("package/*.changes").each do |changes_file|
    changes = File.read(changes_file)
    changes.prepend(entry)
    File.write(changes_file, changes)
  end
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
  next if EXCLUDE_REPOS.include?(repo.name)

  # where to checkout the Git repository
  checkout_dir = File.join(GIT_CHECKOUT_DIR, repo.name)

  if !File.directory?(checkout_dir)
    branches = github.branches(repo.full_name)
    # check only the SP3 packages
    next if !branches.map(&:name).include?(GIT_BRANCH) && !EXTRA_REPOS.include?(repo.name)

    system("git clone #{repo.ssh_url} #{checkout_dir}")
  end

  Dir.chdir(checkout_dir) do
    versions = read_version

    # already at the requested version
    next if versions.all? do |v|
      v.start_with?(NEW_PACKAGE_PREFIX, NEW_DISTRO_PREFIX)
    end

    # not a semantic version name (e.g. a date based version like "20210903")
    if !versions.all? { |v| v.include?(".") }
      puts "Skipping: #{repo.name}-#{versions.join(",")}"
      next
    end

    expected_versioning = versions.all? do |v|
      v.start_with?(NEW_MAJOR_PACKAGE_VERSION, NEW_MAJOR_DISTRO_VERSION)
    end

    # it uses some different versioning, rather do not touch it
    unless expected_versioning
      puts "Skipping: #{repo.name}-#{versions.join(",")}"
      next
    end

    new_version = if versions.any? { |v| v.start_with?(NEW_MAJOR_DISTRO_VERSION) }
      NEW_DISTRO_VERSION
    else
      NEW_PACKAGE_VERSION
    end

    puts "Updating #{repo.name} from #{versions.join(",")} to #{new_version}..."

    next if DRY_RUN

    update_version(new_version)
    update_changes(new_version)
    system("git commit -a -m \"Bump version to #{new_version}\"")
    github.unprotect_branch(repo.full_name, "master")
    system("git push")
    github.protect_branch(repo.full_name, "master", options)
  end
end
