#!/usr/bin/env ruby
# frozen_string_literal: true

#
# This scripts downloads the YaST custom dictionary from
# https://github.com/yast/yast.github.io/blob/master/.spell.yml file
# and saves the dictionary to the $HOME/.hunspell_en_US file
# so it can be used by hunspell for spell checking the Git commit messages
# by overcommit.
#

require "open-uri"
require "yaml"

URL = "https://raw.githubusercontent.com/yast/yast.github.io/master/.spell.yml"
# the default custom dictionary for "en_US" language
DICTIONARY_FILE = "#{Dir.home}/.hunspell_en_US"

text = URI(URL).read
dict = YAML.safe_load(text)["dictionary"]

# merge with the existing dictionary
dict += File.read(DICTIONARY_FILE).split("\n") if File.exist?(DICTIONARY_FILE)

# some extra words
dict += [
  "YaST",
  "bsc",
  "boo",
  "jsc"
]

dict = dict.sort_by(&:downcase)
dict.uniq!
dict.reject!(&:empty?)

puts "Writing #{dict.size} custom words to #{DICTIONARY_FILE}"
File.write(DICTIONARY_FILE, dict.join("\n"))
