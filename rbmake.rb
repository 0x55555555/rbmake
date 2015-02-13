require 'set'
require 'pathname'

module RbMake

module Impl
  module Utils

    def attr_forwarder(*args)
      args.each do |arg|
        
        var_name = "@#{arg}"

        #Here's the getter
        define_method(arg) do
          val = instance_variable_get(var_name)
          if (@parent && val == nil)
            val = @parent.method(arg).call()
            if (val.is_a?(Array))
              val = val.clone
            end
            instance_variable_set(var_name, val)
          end
          next val
        end
        
        define_method("#{arg}=".to_sym) do |val|
          instance_variable_set(var_name, val)
        end

      end
    end
  end

  class Condition
    def self.wrap(val)
      if (val.kind_of?(Condition))
        return val
      end

      return Condition.new(val.to_s)
    end

    def initialize(name)
      @name = name
    end

    def name
      return @name
    end
  end

  class Group
    attr_reader :name, :parent, :owner_module, :groups, :helpers
    attr_accessor :condition

    extend Utils
    attr_forwarder :sources, :include_paths, :dependencies, :flags, :libraries

    def initialize(registry, mod, name, parent)
      @registry = registry

      @helpers = { }
      if (parent)
        parent.helpers.each do |k, v|
          @helpers[k] = v.class.new(v)
        end
      end

      @groups = { }
      @name = name
      @parent = parent
      @owner_module = mod
    end

    def when(cond_input)
      cond = Condition.wrap(cond_input)
      grp = @groups[cond.name]
      if (grp == nil)
        grp = Group.new(@registry, @module, cond.name, self)
        grp.condition = cond

        @groups[cond.name] = grp
        yield(grp) if block_given?
      end

      return grp
    end

    def group(name)
      grp = @groups[name]
      if (grp == nil)
        grp = Group.new(@registry, @module, name, self)
        @groups[name] = grp
        yield(grp) if block_given?
      end

      return grp
    end

    def flat_groups()
      if (@parent != nil)
        return [ @groups.values, @parent.flat_groups ].flatten
      end

      return @groups.values
    end

    def method_missing(sym, *args, &block)
      val = @helpers[sym]
      raise "Invalid method #{sym} for #{self}" unless val
      return val
    end

    def respond_to?(sym, include_private = false)
      return @helpers.include?(sym)
    end

    def first_helper(id)
      val = @helpers[id]
      if (@parent && val == nil)
        return @parent.first_helper(id)
      end
      return val
    end
  end

  class Module < Group
    attr_reader :helpers, :definition
    attr_accessor :generate

    extend Utils
    attr_forwarder :root, :type

    def initialize(registry, name, parent)
      super(registry, self, name, parent)

      @root = ''
      @generate = false
      @definition = nil

      @registry.register_module(self)
    end

    def build(loc, block)
      loc_splits = loc[0].split(":")
      file = loc_splits[0]
      @definition = { :file => file, :line => loc_splits[1].to_i }

      root = @registry.config.root
      @root = Pathname.new(File.dirname(file)).relative_path_from(Pathname.new(root)).cleanpath
      block.call(self, parent)
    end

    def extend_with(helper_id)
      helper = @registry.lookup_helper(helper_id)
      @helpers[helper.name] = helper.create(@parent.first_helper(helper_id))
    end

    def config
      return @registry.config
    end
  end

  class Library < Module
    def initialize(registry, name, parent)
      super
      @generate = true
    end
  end

  class Config
    attr_reader :root

    def initialize(root)
      @root = Pathname.new(File.expand_path(root)).cleanpath
      puts "Source root set to #{@root}"
    end

    def debug(on=true)
      return Condition.new("debug=#{on}")
    end

    def platform(id)
      return Condition.new("platform=#{id}")
    end

  end

  class Registry
    
    attr_reader :config, :modules

    def initialize(config)
      @modules = { }
      @helpers = { }
      @config = config
    end

    def lookup_module(id)
      if (id == nil)
        return nil
      end

      obj = @modules[id]
      raise "Invalid module id #{id}" unless obj

      return obj
    end

    def register_module(mod)
      puts "Registering Module #{mod.name}"
      raise "Module #{hlp.name} re-registered" unless !@helpers.include?(mod.name)
      @modules[mod.name] = mod
    end

    def lookup_helper(id)
      if (id == nil)
        return nil
      end

      obj = @helpers[id]
      raise "Invalid helper id #{id}" unless obj

      return obj
    end

    def register_helper(hlp)
      puts "Registering Helper #{hlp.name}"
      raise "Helper #{hlp.name} re-registered" unless !@helpers.include?(hlp.name)
      @helpers[hlp.name] = hlp
    end
  end

  class CppHelper

    attr_reader :name, :parent

    extend Utils
    attr_forwarder :defines, :flags, :minimum_osx_version

    def initialize(parent)
      @name = :cpp
      @parent = parent
    end

    def create(parent)
      return CppHelper.new(parent)
    end
  end
end

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

conf = RbMake::Impl::Config.new(File.dirname(__FILE__))
$registry = RbMake::Impl::Registry.new(conf)
$registry.register_helper(RbMake::Impl::CppHelper.new(nil))

$:.unshift File.dirname(__FILE__)
require 'EksCore.rb'

def prop(mod, obj, prop)
  this = obj.method(prop).call

  if (!mod)
    parent = obj.parent.method(prop).call
    return this - parent
  end

  return this
end

def generate_group(root, grp, depth)
  mod = grp.is_a?(RbMake::Impl::Module)
  d = "  " * depth
  puts "#{d}GENERATE GROUP #{grp.name}------------------"
  d += "  "
  puts "#{d}CONDITION(#{grp.condition ? grp.condition.name : ""})"
  puts "#{d}LIBRARIES(#{prop(mod, grp, :libraries)})"
  puts "#{d}DEPENDENCIES(#{prop(mod, grp, :dependencies)})"
  puts "#{d}INCLUDE_PATHS(#{prop(mod, grp, :include_paths)})"

  specified_src = prop(mod, grp, :sources)
  if (specified_src)
    src = specified_src.map do |g| 
      path = root + "/" + g
      if (Dir.exist?(path))
        next Dir[path]
      end

      next path
    end
    neat_src = src.map{ |s| Pathname.new(s).cleanpath }
    puts "#{d}SOURCE(#{neat_src.to_a[0..4]})"
  end

  cpp = grp.first_helper(:cpp)
  puts "#{d}DEFINES(#{prop(mod, cpp, :defines)}"
  puts "#{d}FLAGS(#{prop(mod, cpp, :flags)})"
  puts "#{d}OSX_VER(#{cpp.minimum_osx_version})"
  puts

  grps = grp.is_a?(RbMake::Impl::Module) ? grp.flat_groups : grp.groups.values
  grps.each do |v|
    generate_group(root, v, depth + 1)
  end
end

def generate(reg)
  puts "Generating cod"
  reg.modules.values.select{ |l| l.generate }.each do |v|
    puts "Generate #{v.name}"

    raise "Unable to generate modules" if v.class == RbMake::Impl::Module

    puts "ROOT(#{v.root})"
    puts "TARGET #{v.name}"
    puts "TYPE(#{v.type})"

    cpp = v.first_helper(:cpp)
    if (!cpp)
      raise "Cannot generate non-cpp project"
    end

    generate_group(v.root, v, 0)
  end
end

generate($registry)