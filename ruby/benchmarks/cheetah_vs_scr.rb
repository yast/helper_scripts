#! /usr/bin/env ruby

require "yast"
require "yast/y2start_helpers"

require "cheetah"

ENV_VARS = {
  "LANG"    => "C",
  "TERM"    => "dumb",
  "COLUMNS" => "1024"
}

# number of calls to do to have more reliable results
CALLS = 1000

cheetah_opts = [
  stdout: :capture,
  stderr: :capture,
  env:    ENV_VARS
]

def measure(label, &block)
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  CALLS.times { block.call }

  done = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  elapsed = (done - start) * 1000 / CALLS
  puts format("%s: %.2fms per call", label.ljust(10), elapsed)
end

# activate chroot when running in a container
target_dir = ENV["YAST_SCR_TARGET"] || ""
if !target_dir.empty? && target_dir != "/" && File.directory?(target_dir)
  Yast::Y2StartHelpers.redirect_scr(target_dir)
  cheetah_opts << { chroot: target_dir }
end

puts "Number of calls: #{CALLS}"

command = [ "/usr/bin/systemctl", "--plain", "--full", "--no-legend",
  "--no-pager", "--no-ask-password", "list-units", "--all", "--type=target" ]

measure("Cheetah") do
  Cheetah.run(*command, *cheetah_opts)
end

measure("SCR") do
  Yast::SCR.Execute(".target.bash_output",
    ENV_VARS.map{|k, v| "#{k}=#{v}"}.join(" ") + " " + command.join(" "))
end
