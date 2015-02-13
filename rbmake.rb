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
require 'generators/cmake'

conf = RbMake::Impl::Config.new(File.expand_path('.'), :xcode)
puts "Running rbmake for #{ARGV[0]}"
puts "  from #{conf.build_root}"

$registry = RbMake::Impl::Registry.new(conf)
$registry.register_helper(RbMake::Impl::CppHelper.new(nil))

module RbMake

def self.module(name, parent, &blk)
  parent_object = $registry.lookup_module(parent)
  impl = Impl::Module.new($registry, name, parent_object)
  impl.build(caller, blk)
end


def self.library(name, parent, &blk)
  parent_object = $registry.lookup_module(parent)
  impl = Impl::Library.new($registry, name, parent_object)
  impl.build(caller, blk)
end

end

require ARGV[0]

generate(conf, $registry)