#!/usr/bin/env ruby

# This script bumps the version in all YaST packages
#
# You need admin access rights to temporarily disable the GitHub branch protection
# and allow direct push to "master".
#

require "optparse"

require_relative "../github_actions/gh_helpers"

############# start of editable values ############

# new package version
NEW_PACKAGE_VERSION = "4.5.0".freeze

# some packages use distro based version
NEW_DISTRO_VERSION = "15.5.0".freeze

# author + email, written into the changes files
AUTHOR = "Ladislav Slezák <lslezak@suse.cz>".freeze

# change only packages which have this branch defined
GIT_OLD_BRANCH = "SLE-15-SP3".freeze

# new branch to create
GIT_NEW_BRANCH = "SLE-15-SP4".freeze

# new branch for openSUSE specific packages
GIT_OPENSUSE_NEW_BRANCH = "openSUSE-15_4".freeze

# bug number used in the *.changes files
BUG_NR = "1198109".freeze

# Rakefile submit target
SUBMIT_TARGET = "sle15sp4"

OBS_SUBMIT = <<TEXT
  conf.obs_api = "https://api.opensuse.org"
  conf.obs_target = "openSUSE_Leap_15.4"
  conf.obs_sr_project = "openSUSE:Leap:15.4:Update"
  conf.obs_project = "YaST:openSUSE:15.4"
TEXT

############# end of editable values ############

gh_organization = "yast"
gh_repository = nil
confirm_diff = false

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

  opts.on("-o", "--organization=ORGANIZATION", "GitHub organization (default \"yast\", optionally \"libyui\"") do |o|
    gh_organization = o
  end

  opts.on("-r", "--repository=REPOSITORY", "Run only for the specified repository") do |r|
    gh_repository = r
  end

  opts.on("-c", "--confirm", "Show diff and confirm the changes before committing them") do |d|
    confirm_diff = d
  end
end.parse!

# for checking whether the version has been already bumped
NEW_PACKAGE_PREFIX = NEW_PACKAGE_VERSION[0..-2]
# prefix of the distro version
NEW_DISTRO_PREFIX = NEW_DISTRO_VERSION[0..-2].freeze

# the major version prefix of the package version
NEW_MAJOR_PACKAGE_VERSION = NEW_PACKAGE_VERSION.split(".").first + "."
# the major version prefix of the distro version
NEW_MAJOR_DISTRO_VERSION = NEW_DISTRO_VERSION.split(".").first + "."

# subdirectory where to clone Git repositories
GIT_CHECKOUT_DIR = "github".freeze

# skip these repositories
SPECIAL_VERSIONS = [
  # this is a Ruby gem, not an YaST module
  "yast-rake",
  # these are bound to the SUSE Manager version, not the SLE version
  "skelcd-control-suse-manager-proxy",
  "skelcd-control-suse-manager-server"
].freeze

# these repositories are openSUSE Leap only (not in SLE)
OPENSUSE_REPOS = [
  "yast-alternatives",
  "yast-docker",
  "yast-migration-sle",
  "yast-slp-server"
].freeze

def spec_files
  Dir.glob("package/*.spec")
end

# read the package version from the spec file(s)
def read_versions
  spec_files.map do |spec_file|
    spec = File.read(spec_file)
    spec.match(/^\s*Version:\s*(\S+)$/)[1]
  end
end

# set the new version in the spec files(s)
def update_specfiles(version)
  spec_files.each do |spec_file|
    spec = File.read(spec_file)
    spec.gsub!(/^(\s*)Version:(\s*).*$/, "\\1Version:\\2#{version}")
    File.write(spec_file, spec)
  end
end

def update_version(repo, new_version)
  # repository with special versioning?
  return if SPECIAL_VERSIONS.include?(repo.name)

  versions = read_versions

  # already at the requested version
  return if versions.all? do |v|
    v.start_with?(NEW_PACKAGE_PREFIX, NEW_DISTRO_PREFIX)
  end

  # not a semantic version name (e.g. a date based version like "20210903")
  if !versions.all? { |v| v.include?(".") }
    puts "Skipping: #{repo.name}-#{versions.join(",")}"
    return
  end

  expected_versioning = versions.all? do |v|
    v.start_with?(NEW_MAJOR_PACKAGE_VERSION, NEW_MAJOR_DISTRO_VERSION)
  end

  # it uses some different versioning, rather do not touch it
  unless expected_versioning
    puts "Skipping: #{repo.name}-#{versions.join(",")}"
    return
  end

  puts "Updating #{repo.name} from #{versions.join(",")} to #{new_version}..."

  update_specfiles(new_version)
end

# have the same time entry for all packages
TIME_ENTRY = Time.now.utc.strftime("%a %b %d %T UTC %Y")

def update_changes(version)
  entry = <<EOF
-------------------------------------------------------------------
#{TIME_ENTRY} - #{AUTHOR}

- Bump version to #{version} (bsc##{BUG_NR})

EOF

  Dir.glob("package/*.changes").each do |changes_file|
    changes = File.read(changes_file)
    changes.prepend(entry)
    File.write(changes_file, changes)
  end
end

def modify_opensuse_rakefile(file, lines, rake_namespace)
  line_index = lines.index { |l| l =~ /^\s*#{rake_namespace}::Tasks.configuration do \|conf\|/ }
  fail "Cannot modify #{file}" unless line_index

  lines.insert(line_index + 1, OBS_SUBMIT, "\n")
  File.write(file, lines.join(""))
end

def modify_sle_rakefile(file, lines, rake_namespace)
  submit_to = "#{rake_namespace}::Tasks.submit_to"

  new_line = "#{submit_to} :#{SUBMIT_TARGET}\n"
  line_index = lines.index { |l| l =~ /#{submit_to}/ }
  if line_index
    lines[line_index] = new_line
  else # line is not there yet, so place it below require line
    line_index = lines.index { |l| l =~ /^\s*require.*#{rake_namespace.downcase}\/rake/ }
    lines.insert(line_index + 1, "\n", new_line)
  end

  File.write(file, lines.join(""))
end

def modify_rakefile(repo)
  file = "Rakefile"
  raise "Cannot find Rakefile in #{Dir.pwd}" unless File.exist?(file)

  lines = File.readlines(file)

  # Ruby name space of the Rake tasks,
  # "Yast" for YaST, "Libyui" for libyui
  rake_namespace = repo.owner.login.capitalize

  if OPENSUSE_REPOS.include?(repo.name)
    modify_opensuse_rakefile(file, lines, rake_namespace)
  else
    modify_sle_rakefile(file, lines, rake_namespace)
  end
end

def modify_github_actions
  Dir[".github/workflows/*.{yml,yaml}"].each do |file|
    content = File.read(file)

    # replace the Docker image name
    # FIXME: adapt also for the libyui repositories
    content.gsub!(
      "registry.opensuse.org/yast/head/containers_${{matrix.distro}}/",
      "registry.opensuse.org/yast/sle-15/sp4/containers/"
    )
    content.gsub!(
      "registry.opensuse.org/yast/head/containers/",
      "registry.opensuse.org/yast/sle-15/sp4/containers/"
    )

    # remove the build matrix
    content.gsub!(/^\s+distro:.*\n/, "")
    content.gsub!(/^\s+matrix:.*\n/, "")

    File.write(file, content)
  end
end

def new_branch_name(repo)
  OPENSUSE_REPOS.include?(repo.name) ? GIT_OPENSUSE_NEW_BRANCH : GIT_NEW_BRANCH
end

def create_new_branch(repo)
  new_branch = new_branch_name(repo)
  system("git checkout -b #{new_branch}")
  new_branch
end

def bump_version(repo)
  versions = read_versions

  # already at the requested version
  return if versions.all? do |v|
    v.start_with?(NEW_PACKAGE_PREFIX, NEW_DISTRO_PREFIX)
  end

  # not a semantic version name (e.g. a date based version like "20210903")
  if !versions.all? { |v| v.include?(".") }
    puts "Skipping: #{repo.name}-#{versions.join(",")}"
    return
  end

  expected_versioning = versions.all? do |v|
    v.start_with?(NEW_MAJOR_PACKAGE_VERSION, NEW_MAJOR_DISTRO_VERSION)
  end

  # it uses some different versioning, rather do not touch it
  unless expected_versioning
    puts "Skipping: #{repo.name}-#{versions.join(",")}"
    return
  end

  new_version = if versions.any? { |v| v.start_with?(NEW_MAJOR_DISTRO_VERSION) }
    NEW_DISTRO_VERSION
  else
    NEW_PACKAGE_VERSION
  end

  puts "Updating #{repo.name} from #{versions.join(",")} to #{new_version}..."

  update_version(repo, new_version)
  update_changes(new_version)

  new_version
end

def git_clone(repo, checkout_dir)
  if !File.directory?(checkout_dir)
    system("git clone --depth 1 #{repo.ssh_url} #{checkout_dir}")
  else
    Dir.chdir(checkout_dir) do
      system("git pull --rebase")
    end
  end
end

def create_branch?(client, repo)
  branches = client.branches(repo.full_name).map(&:name)

  if OPENSUSE_REPOS.include?(repo.name)
    # new openSUSE branch not created
    !branches.include?(GIT_OPENSUSE_NEW_BRANCH)
  else
    # branch not created yet and the old branch is present
    !branches.include?(GIT_NEW_BRANCH) && branches.include?(GIT_OLD_BRANCH)
  end
end

def create_branch(client, repo, confirm)
  # create the maintenance branch and modify the Rakefile and GitHub Actions
  new_branch = create_new_branch(repo)
  puts "Creating branch #{new_branch}..."

  modify_rakefile(repo)
  modify_github_actions

  system("git --no-pager diff")
  return false if confirm && !commit_confirmed?

  # commit the changes and push the new branch, enable branch protection
  system("git commit -a -m \"Adapt files for the #{new_branch} branch\"")
  commit = `git rev-parse HEAD`
  system("git push --set-upstream origin #{new_branch}")
  client.protect_branch(repo.full_name, new_branch, BRANCH_PROTECTION)

  # checkout master, merge the maintenance branch and revert the modifications
  # to have a clean merge later
  system("git checkout master")
  system("git merge #{new_branch}")
  system("git revert --no-edit #{commit}")

  # push to master, temporarily disable branch protection
  with_unprotected(client, repo.full_name, repo.default_branch) do
    system("git push")
  end

  # bump the package version in master
  new_version = bump_version(repo)

  if new_version
    system("git --no-pager diff")
    return false if confirm && !commit_confirmed?

    system("git commit -a -m \"Bump version to #{new_version}\"")
  end

  # push to master, temporarily disable branch protection
  with_unprotected(client, repo.full_name, repo.default_branch) do
    system("git push")
  end

  true
end

client = gh_client
git_repos = gh_repos(client, gh_organization)

git_repos.each do |repo|
  next if gh_repository && repo.name != gh_repository

  if !create_branch?(client, repo)
    puts "Skipping repository #{repo.name}"
    next
  end

  puts "Branching repository #{repo.name}"

  # where to checkout the Git repository
  checkout_dir = File.join(GIT_CHECKOUT_DIR, repo.name)
  git_clone(repo, checkout_dir)

  Dir.chdir(checkout_dir) do
    create_branch(client, repo, confirm_diff)
  end
end
