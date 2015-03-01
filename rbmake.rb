#!/usr/bin/env ruby

require 'set'
require 'pathname'
require 'pry'
require 'Readline'

$:.unshift File.dirname(__FILE__) + '/lib'

require 'condition'
require 'config'
require 'library'
require 'module'
require 'registry'
require 'utils'
require 'helpers/cpp'
require 'generators/cmake/cmake'

conf = RbMake::Impl::Config.new(File.expand_path('.'), :xcode)
input_file = ARGV[0]
if (input_file == nil || (File.exist?(input_file) && Dir.exist?(input_file)))
  path = '.'
  if (input_file)
    path = input_file
  end

  expanded = File.expand_path(path)

  name =  File.basename(expanded)
  input_file = expanded + "/#{name}.rb"
end
raise "Invalid input file #{input_file}" unless File.exist?(input_file)
puts "Running rbmake for #{input_file}"
puts "  from #{conf.build_root}"

$registry = RbMake::Impl::Registry.new(conf)
$registry.register_helper(RbMake::Impl::CppHelper.new("N/A", nil, nil))

module RbMake

def self.module(name, parent=nil, &blk)
  parent_object = $registry.lookup_module(parent)
  impl = Impl::Module.new($registry, name, parent_object)
  impl.build(caller, blk)
end


def self.library(name, parent=nil, &blk)
  parent_object = $registry.lookup_module(parent)
  impl = Impl::Library.new($registry, name, parent_object)
  impl.build(caller, blk)
end

def self.import_module(name, raise_on_fail=true)
  src = name
  if (!File.exist?(src))
    file, line = Impl::Utils.caller_file()
    relative_dir = File.dirname(file)
    base = File.basename(name)
    src = "#{relative_dir}/#{name}/#{base}.rb"
  end
  if (File.exist?(src))
    puts "Import #{name}"
    require(src)
  else
    if (raise_on_fail)
      raise "Invalid module #{name} (#{src})"
    end
  end
end

def self.import_modules(pattern)
  file, line = Impl::Utils.caller_file()
  relative_dir = File.dirname(file)
  pattern = "#{relative_dir}/#{pattern}"
  puts "Importing #{pattern}"
  Dir[pattern].each do |e|
    if (!Dir.exist?(e))
      next
    end
    name = File.basename(e)
    path = e + "/#{name}.rb"
    import_module(path, false)
  end
end

end

require input_file

generate(File.basename(input_file, ".*"), conf, $registry)