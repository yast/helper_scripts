#!/usr/bin/env ruby

# This script bumps the version in all YaST packages
#
# You need admin access rights to temporarily disable the GitHub branch protection
# and allow direct push to "master".
#

# the GitHub organization
GH_ORG = "yast".freeze

# install missing gems
if !File.exist?("./.vendor")
  puts "Installing the needed Rubygems to ./.vendor/bundle ..."
  system "bundle install --path .vendor/bundle"
end

require "rubygems"
require "bundler/setup"

require "octokit"

DRY_RUN = ENV["DRY_RUN"]

# new package version
NEW_PACKAGE_VERSION = "4.4.0".freeze
# for checking whether the version has been already bumped
NEW_PACKAGE_PREFIX = NEW_PACKAGE_VERSION[0..-2]

# some packages use distro based version
NEW_DISTRO_VERSION = "15.4.0".freeze
NEW_DISTRO_PREFIX = NEW_DISTRO_VERSION[0..-2].freeze

# subdirectory where to clone Git repositories
GIT_CHECKOUT_DIR = "github".freeze

# skip these repositories
EXCLUDE_REPOS = [
  # this is a Ruby gem, not an YaST module
  "yast-rake",
  # these are bound to the SUSE Manager version, not the SLE version
  "skelcd-control-suse-manager-proxy",
  "skelcd-control-suse-manager-server"
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
def set_version(version)
  spec_files.each do |spec_file|
    spec = File.read(spec_file)
    spec.gsub!(/^\s*Version:.*$/, "Version:        #{version}")
    File.write(spec_file, spec)
  end
end

TIME_ENTRY = Time.now.utc.strftime("%a %b %d %T UTC %Y")

def update_changes(version)
  entry = <<EOF
-------------------------------------------------------------------
#{TIME_ENTRY} - Ladislav Slezák <lslezak@suse.cz>

- #{version}

EOF

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
    $stderr.puts "Error: The Github access token is not set."
    $stderr.puts "Pass it via the 'GH_TOKEN' environment variable"
    $stderr.puts "or write it to the ~/.netrc file."
    $stderr.puts "See https://github.com/octokit/octokit.rb#using-a-netrc-file"
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
    next unless branches.map(&:name).include?("SLE-15-SP3")

    system("git clone #{repo.ssh_url} #{checkout_dir}")
  end

  Dir.chdir(checkout_dir) do
    versions = read_version

    # already at the requested version
    next if versions.all? do |v|
      v.start_with?(NEW_PACKAGE_PREFIX) || v.start_with?(NEW_DISTRO_PREFIX)
    end

    # not a semantic version name (e.g. a date based version like "20210903")
    if !versions.all? { |v| v.include?(".") }
      puts "Skipping: #{repo.name}-#{versions.join(",")}"
      next
    end

    # it uses some different versioning, rather do not touch it
    unless versions.all? { |v| v.start_with?("4.") || v.start_with?("15.") }
      puts "Skipping: #{repo.name}-#{versions.join(",")}"
      next
    end

    new_version = versions.any? { |v| v.start_with?("15.") } ? NEW_DISTRO_VERSION : NEW_PACKAGE_VERSION
    puts "Updating #{repo.name} from #{versions.join(",")} to #{new_version}..."

    next if DRY_RUN

    set_version(new_version)
    update_changes(new_version)
    system("git commit -a -m \"Bump version to #{new_version}\"")
    github.unprotect_branch(repo.full_name, "master")
    system("git push")
    github.protect_branch(repo.full_name, "master", options)
  end
end
