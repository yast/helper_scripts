#!/usr/bin/env ruby

# This script modifies the YaST job configurations globally.
#
# Pass the Jenkins credentials via "JENKINS_USER" and "JENKINS_PASSWORD"
# environment variables.

require "rexml/document"

require_relative "jenkins_scripts"
jenkins_setup

jenkins = jenkins_client

# all YaST jobs
jenkins_jobs = jenkins.job.list_all.select { |j| j.start_with?("yast-") }
puts "Found #{jenkins_jobs.size} jobs"

new_xml = "<hudson.triggers.SCMTrigger><spec># everyday some time between 1:00AM and 2:59AM\n" \
  "H H(1-2) * * *</spec></hudson.triggers.SCMTrigger>"
new_node = REXML::Document.new(new_xml).root

jenkins_jobs.each_with_index do |job, index|
  puts "[#{100 * index / jenkins_jobs.size}% #{index + 1}/#{jenkins_jobs.size}] Modifying job #{job}..."

  xml = jenkins.get_config("/job/#{job}")
  xmldoc = REXML::Document.new(xml)

  poll = xmldoc.elements["//project/triggers/hudson.triggers.SCMTrigger"]

  # remove the poll config if already present
  if poll
    puts "Polling interval already defined: #{poll.elements["spec"].text}"
    xmldoc.elements.delete("//project/triggers/hudson.triggers.SCMTrigger")
  end

  # add the new config
  xmldoc.elements["//project/triggers"].add_element(new_node)

  jenkins.post_config("/job/#{job}/config.xml", xmldoc.to_s)
end
