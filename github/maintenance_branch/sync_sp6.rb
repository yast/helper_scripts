#!/usr/bin/env ruby

# This script copies the missing changes from IBS to Git. It is a single purpose
# script shared just for reference when we need to do something similar again.
#
# You need admin access rights to temporarily disable the GitHub branch protection
# and allow direct push without pull requests.
#

require "shellwords"
require "find"
require "fileutils"

require_relative "../github_actions/gh_helpers"


gh_organization = "yast"

# subdirectory where to clone Git repositories
GIT_CHECKOUT_DIR = "github".freeze

def git_clone(repo, checkout_dir)
  if File.directory?(checkout_dir)
    Dir.chdir(checkout_dir) do
      system("git reset --hard")
      system("git pull --rebase")
    end
  else
    system("git clone #{repo.ssh_url} #{checkout_dir}")
  end
end

def find_file(file, dir)
  Find.find(dir) do |path|
    return path if File.basename(path) == file
  end

  nil
end

def confirmed?
  msg = "\nCommit the change? [N/y] "
  print msg

  input = nil
  loop do
    input = $stdin.gets.strip
    break if ["Y", "y", "N", "n", ""].include?(input)

    print "Invalid input#{msg}"
  end

  ["Y", "y"].include?(input)
end

client = gh_client
git_repos = gh_repos(client, gh_organization)
removed = []

r2 = ["system-role-xen", "yast-slp", "yast-testsuite"]
git_repos.select!{|r| r2.include?(r.name)}

git_repos.each do |repo|
  branches = client.branches(repo.full_name).map(&:name)
  next unless branches.include?("SLE-15-SP6")

  # separate the output for each package
  puts "\e[32m" + ("-" * 80) + "\e[0m"
  puts repo.full_name

  # where to checkout the Git repository
  checkout_dir = File.join(GIT_CHECKOUT_DIR, repo.name)
  git_clone(repo, checkout_dir)

  Dir.chdir(checkout_dir) do
    system("git checkout SLE-15-SP6")
    # find the package name, expand the macros, some packages use a macro in the name
  end
  
  pkg = `find #{checkout_dir.shellescape} -name '*.spec' | grep -v /test/ | xargs cat | grep ^Name: | sed -e 's/^Name:\\s*//' | sort | head -n1`.chomp

  # expand the RPM macros when needed
  if pkg.include?("%")
      pkg = `find #{checkout_dir.shellescape} -name '*.spec' | grep -v /test/ | xargs rpmspec --parse | grep ^Name: | sed -e 's/^Name:\\s*//' | sort | head -n1`.chomp
  end

  if pkg.empty?
    puts "Package in #{repo.name} not found!"
    gets
    next
  end

  osc_dir = File.join("SUSE:SLE-15-SP6:Update", pkg)

  # checkout the package from IBS
  if !File.exist?(osc_dir)
    system("osc -A https://api.suse.de co SUSE:SLE-15-SP6:Update #{pkg.shellescape}")
  end

  Find.find(osc_dir) do |obs_path|
    obs_file = File.basename(obs_path)

    # skip the .osc subdirectory
    if File.directory?(obs_path) && obs_file == ".osc"
      Find.prune
    else
      next if File.directory?(obs_path)
      git_path = find_file(obs_file, checkout_dir)

      if git_path
        # copy the file
        FileUtils.cp(obs_path, git_path, verbose: true)
      # ignore the tarballs
      elsif !obs_path.include?(".tar.")
        warn "File #{obs_file} not found in Git!"
      end
    end
  end

  # show the diff
  Dir.chdir(checkout_dir) do
    diff = `git --no-pager diff`

    # no change found
    next if diff.empty?

    puts diff
    next unless confirmed?

    if branches.include?("SLE-15-SP7")
      puts "SP7 diff:"
      system("git diff SLE-15-SP6..origin/SLE-15-SP7")
      next unless confirmed?
    end

    # commit the changes
    system("git commit -a -m \"Import the changes from the OBS SLE15-SP6 project\"")

    # push the changes (temporarily disable the branch protection)
    with_unprotected(client, repo.full_name, "SLE-15-SP6") do
      system("git push")
    end

    # delete the SP7 branch if it exists (branch it again from the updated SP6 separately)
    if branches.include?("SLE-15-SP7")
      client.unprotect_branch(repo.full_name, "SLE-15-SP7")
      system("git push origin --delete SLE-15-SP7")

      removed.append(repo.name)
    end

  end
end

puts "Removed SP7 branch from #{removed.size} repositories: #{removed.inspect}"
