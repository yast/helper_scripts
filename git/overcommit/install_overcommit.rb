#!/usr/bin/env ruby
# frozen_string_literal: true

#
# This scripts automatically installs the Overcommit Git hooks.
# It scans the subdirectories recursively for Git repositories.
#
# Usage:
#   ./install_overcommit.rb [path]
#
# If path is given it scans that directory, if not specified it scans
# the current directory.
#
# See https://github.com/sds/overcommit for more details about
# the Overcommit tool.

require "erb"
require "find"

# Overcommit configuration file
OVERCOMMIT_CFG = ".overcommit.yml"

def install_overcommit(dir, template)
  # skip if overcommit it is already present
  overcommit_file = File.join(dir, OVERCOMMIT_CFG)
  return if File.exist?(overcommit_file)

  @add_rubocop = File.exist?(File.join(dir, ".rubocop.yml")) && File.exist?(File.join(dir, "Rakefile"))

  @test_command = if File.exist?(File.join(dir, "Makefile.cvs"))
    ["make", "check"]
  # regexp from the test:unit rake task
  elsif !Dir["#{dir}/**/test/**/*_{spec,test}.rb"].empty? && File.exist?(File.join(dir, "Rakefile"))
    ["rake", "test:unit"]
  end

  # "<>" means no extra space after <% %>
  erb = ERB.new(template, nil, "<>")
  # write the config file
  File.write(overcommit_file, erb.result(binding))

  # hide the file for git, append the file name to .git/info/exclude
  File.open(File.join(dir, ".git/info/exclude"), "a") do |f|
    f.puts "/.overcommit.yml"
  end

  # install the overcommit hooks
  Dir.chdir(dir) do
    system "overcommit --install"
    system "overcommit --sign"
  end

  puts "Installed in #{File.basename(dir)}"
end

start = ARGV[0] || "."

template = File.read(File.join(__dir__, "overcommit_template.yml.erb"))

# recursively find Git repositories
Find.find(start) do |path|
  # a Git repository?
  next unless File.directory?(File.join(path, ".git"))

  install_overcommit(path, template)

  # stop searching in the subdirectories
  Find.prune
end
