
# install missing gems
if !File.exist?("./.vendor")
  puts "Installing the needed Rubygems to ./.vendor/bundle ..."
  system "bundle install --path .vendor/bundle"
end

require "rubygems"
require "bundler/setup"

require "octokit"

# create the octokit client
def gh_client
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

def gh_repos(client, org)
  puts "Reading #{org.inspect} repositories at GitHub..."
  git_repos = client.list_repositories(org)
  puts "Found #{git_repos.size} Git repositories\n\n"
  git_repos
end

def with_unprotected(client, repo, branch, &block)
  return unless block_given?

  client.unprotect_branch(repo, branch)

  begin
    block.call
  ensure
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

    client.protect_branch(repo, branch, options)
  end
end

# ask user to confirm the changes before git push
def commit_confirmed?
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
