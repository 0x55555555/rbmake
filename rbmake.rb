#!/usr/bin/env ruby

require 'set'
require 'pathname'

$:.unshift File.dirname(__FILE__) + '/lib'

require 'condition'
require 'config'
require 'library'
require 'module'
require 'registry'
require 'utils'
require 'helpers/cpp'
require 'generators/cmake/cmake'

Commands = [ :generate, :build, :test ]
command = ARGV[0].to_sym
variant = (ARGV[2] || :debug).to_sym
if (!Commands.include?(command))
  raise "Invalid command '#{command}'"
end

conf = RbMake::Impl::Config.new(File.expand_path('.'), false)
input_file = RbMake::Impl::Utils::find_best_input(ARGV[1])
puts "Running rbmake for #{input_file}"
puts "  from #{conf.build_root}"

registry = RbMake::Impl::Registry::load(input_file, conf)
raise "Invalid registry loaded from '#{input_file}'" unless registry

if (command == :generate)
  generate_cmake(File.basename(input_file, ".*"), conf, registry, :xcode, variant)
end

if (command == :build)
  generate_cmake(File.basename(input_file, ".*"), conf, registry, :make, variant)
  system("make")
  return $?.exitstatus
end

if (command == :test)
  system("make test")
  return $?.exitstatus
end
