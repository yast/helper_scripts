#!/usr/bin/env ruby

# This script adds a build matrix
#
# You need admin access rights to temporarily disable the GitHub branch protection
# and allow direct push to GitHub without a review".
#

require_relative "gh_helpers"

# the GitHub organization
GH_ORG = "yast".freeze

# optionally do not confirm the changes
CONFIRM = ENV["CONFIRM"] != "0"

# subdirectory where to clone Git repositories
GIT_CHECKOUT_DIR = "github".freeze

def workflow_files
  Dir.glob(".github/workflows/*.yml") + Dir.glob(".github/workflows/*.yaml")
end

def run_on_tw(content, job)
  content.gsub!(
    # (?:(?!distro).)* = anything except "distro", this is a non-greedy version of .*
    # (: starts a non-capturing group
    # (?! is a negative lookahead assertion
    # https://ruby-doc.org/core-2.5.0/Regexp.html#class-Regexp-label-Anchors
    # (Next time try a simpler lazy match, #{job}:.*?distro:
    /(#{job}:(?:(?!distro).)*distro: )[^\n]*\n/m,
    "\\1 [ \"tumbleweed\", \"leap_latest\" ]\n"
  )
end

def modify_workflow(content)
  new_content = content.dup

  snippet = <<-EOT.chomp

    strategy:
      fail-fast: false
      matrix:
        distro: [ "leap_latest" ]

    container:
      image: registry.opensuse.org/yast/head/containers_${{matrix.distro}}/yast-ruby
EOT

  new_content.gsub!(
    /^\s*container:\n*\s*image:\s*registry\.opensuse\.org\/yast\/head\/containers\/yast-ruby:latest/,
    snippet
  )

  snippet = <<-EOT.chomp
      # send it only from the TW build to avoid duplicate submits
      if: ${{ matrix.distro == 'tumbleweed' }}
      uses: coverallsapp/github-action@master
EOT

  new_content.gsub!(
    /^\s*uses: coverallsapp\/github-action@master/,
    snippet
  )

  run_on_tw(new_content, "Tests")
  run_on_tw(new_content, "Package")

  new_content
end

def update_workflow(file)
  # unfortunately we cannot use "YAML.load_file" and ".to_yaml" later as it would
  # remove the comments and reformat the document :-(
  content = File.read(file)

  # skip if the Ruby image is not present
  if !content.include?("registry.opensuse.org/yast/head/containers/yast-ruby") ||
      # or the build matrix is already present
      content.include?("distro: [ \"leap_latest\" ]")

    return false
  end

  new_content = modify_workflow(content)

  changed = new_content != content
  File.write(file, new_content) if changed
  changed
end

client = gh_client

gh_repos(client, GH_ORG).each do |repo|
  # where to checkout the Git repository
  checkout_dir = File.join(GIT_CHECKOUT_DIR, repo.name)

  # already cloned?
  if !File.directory?(checkout_dir)
    puts
    # we do not need the complete history, use depth=1
    system("git clone --depth 1 #{repo.ssh_url} #{checkout_dir}")
  end

  Dir.chdir(checkout_dir) do
    # no change
    next if workflow_files.map { |f| update_workflow(f) }.none?

    puts "Updating GitHub Actions:"
    system("git --no-pager diff")

    next if CONFIRM && !commit_confirmed?

    system("git commit -a -m \"Added build matrix to GitHub Actions\"")

    with_unprotected(client, repo.full_name, repo.default_branch) do
      system("git push")
    end
  end
end
