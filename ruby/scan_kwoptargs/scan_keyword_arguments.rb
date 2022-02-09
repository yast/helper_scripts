#! /usr/bin/env ruby

# This script tries to find the places where the keyword arguments are passed
# instead of a hash.
# See bug https://bugzilla.suse.com/show_bug.cgi?id=1195226#c4
#
# Usage: ./scan_keyword_arguments.rb <directory>
#
# It scans all *.rb files under that specified directory, if missing it scans
# from the current directory.
#
# This script is not perfect:
# - it does not match a variable with it's class, it can only work properly
#   with the static YaST modules
# - it does not check the namespace (e.g. cannot distinguish between
#   Yast2::Popup and Yast::Popup)
# - does not check optional arguments, like in "foo(bar, baz = nil, bax: nil)"
#
# But as this is just one time script it is easy to manually check the results.
#
# Links:
# - https://docs.rubocop.org/rubocop-ast/index.html
# - https://docs.rubocop.org/rubocop-ast/node_types.html
#
# This script runs two passes, in the first one it collects the method definitions,
# in the second one it tries to match all method calls with method definitions
# and find the difference in the arguments.
#
# You can use "ruby-parse" tool to see the parsed AST for a specific Ruby code,
# e.g. "ruby-parse -e 'foo(bar: baz)'".
#
# Testing:
#  mkdir test
#  curl https://raw.githubusercontent.com/yast/yast-yast2/c9127aad823c9d909f58940745ba981547c5f37f/library/cwm/src/modules/CWM.rb > test/CWM.rb
#  curl https://raw.githubusercontent.com/yast/yast-iscsi-client/fe946fdb9a12dda6fb062786129dbbed99ca5263/src/include/iscsi-client/dialogs.rb > test/dialogs.rb
#  ./scan_keyword_arguments.rb test

# install missing gems
unless File.exist?("./.vendor")
  puts "Installing the needed Rubygems to ./.vendor/bundle ..."
  system "bundle install --path .vendor/bundle"
end

require "rubygems"
require "bundler/setup"

require "rubocop-ast"

# helper method to find the parent class node
def find_parent_class_name(node)
  parent_node = node.parent
  # no parent
  return nil if parent_node.nil?

  # found a class
  if parent_node.class_type?
    # only constant class name
    return parent_node.identifier.short_name if parent_node.identifier.const_type?

    return nil
  end

  # search recursively
  find_parent_class_name(parent_node)
end

# a human readable node location in the source file (in "file:line" format)
def node_location(node)
  "#{node.location.expression.source_buffer.name}:#{node.location.line}"
end

# Collect all methods which use keyword arguments
class MethodCollector < Parser::AST::Processor
  include RuboCop::AST::Traversal

  attr_reader :kwoptarg_methods

  # TODO: maybe use a node pattern matching here?
  # https://docs.rubocop.org/rubocop-ast/node_pattern.html
  # extend RuboCop::AST::NodePattern::Macros
  # def_node_matcher :method_with_kwoptarg?, '(def ?????)'

  def initialize
    @kwoptarg_methods = Set.new
    super
  end

  def on_def(node)
    if node.arguments.any?(&:kwoptarg_type?) && node.arguments.any?(&:arg_type?) && find_parent_class_name(node)
      # puts "Found method with kwoptargs #{node.method_name.to_s.inspect} at " \
      #    "#{node.location.expression.source_buffer.name}:#{node.location.line}"
      kwoptarg_methods << node
    end
  end
end

# Check if the called method matches the definition
class CallChecker < Parser::AST::Processor
  include RuboCop::AST::Traversal

  attr_reader :method_defs

  def initialize(definitions)
    @method_defs = definitions
    super()
  end

  def on_send(node)
    # none receiver
    return if node.receiver.nil? || !node.receiver.const_type?

    # find the method definition, ignore the "Class" suffix for the YaST modules
    called = method_defs.find do |d|
      method_class_name = find_parent_class_name(d)

      d.method_name == node.method_name &&
        (
          method_class_name == node.receiver.short_name ||
          method_class_name.to_s.gsub(/Class$/, "") == node.receiver.short_name.to_s
        )
    end

    return unless called

    # the number of non keyword arguments should match
    arg_types_called = node.arguments.map(&:type) - [:kwargs]
    arg_types_defined = called.arguments.map(&:type) - [:kwoptarg]
    if arg_types_called.size != arg_types_defined.size
      puts "Mismatch: #{node.receiver.short_name}::#{node.method_name} (#{node_location(called)}) " \
           "called from from #{node_location(node)}"
    end
  end
end

def process_all_ruby_files(start_dir, node_type, processor)
  Dir["#{start_dir}/**/*.rb"].each do |file|
    next if file.include?("vendor/")

    # use Ruby 2.5 parser
    source = RuboCop::AST::ProcessedSource.new(File.read(file), 2.5, file)
    puts "ERROR: #{file}: #{source.parser_error}" if source.parser_error
    source.ast&.each_node(node_type) { |n| processor.process(n) }
  end
end

dir = ARGV[0] || "."

collector = MethodCollector.new

# disable default legacy kwargs handling, that returns keyword parameters a Hash
# so then it is not possible to distinguish between "foo(bar: baz)" and "foo({bar: baz})"
RuboCop::AST::Builder.send(:"emit_kwargs=", true)

# the first pass - find the defined methods with keyword arguments
process_all_ruby_files(dir, :def, collector)

puts "Failed Checks"
puts "-------------"

# the second pass - check the method calls arguments
checker = CallChecker.new(collector.kwoptarg_methods)
process_all_ruby_files(dir, :send, checker)
