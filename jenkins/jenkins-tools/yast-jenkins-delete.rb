#! /usr/bin/env ruby
# frozen_string_literal: true

# script for mass delete of jobs in our jenkins
# credentials stored in jenkins.yml
# modify JOB_NAME_PATTERN before use to specify pattern of job to delete

require "yaml"

conf = YAML.safe_load(File.read("jenkins.yml"))
USER = conf["username"]
PWD  = conf["password"]
URL_BASE = "https://#{USER}:#{PWD}@ci.opensuse.org"
# URL_BASE = "http://river.suse.de"
# %s is replaced by arguments passed to program
JOB_NAME_PATTERN = "yast-%s-test"

ARGV.each do |mod|
  # address to delete from http://jenkins-ci.361315.n4.nabble.com/Deleting-a-job-through-the-Remote-API-td3622851.html
  `curl -X POST #{URL_BASE}/job/#{JOB_NAME_PATTERN % mod}/doDelete`
end
