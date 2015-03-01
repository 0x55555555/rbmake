require 'condition'
require 'utils'

module RbMake
module Impl

class Group
  attr_reader :name, :parent, :resolve_parent, :owner_module, :groups, :helpers, :resolved_dependencies
  attr_accessor :condition, :extra

  extend Utils
  attr_forwarder :sources, :exclude_sources, :include_paths, :dependencies, :libraries, :debug_generate

  def initialize(registry, mod, name, parent, resolve_parent)
    @registry = registry

    @helpers = { }
    if (parent)
      parent.helpers.each do |k, v|
        parent_obj = resolve_parent ? v : nil
        add_helper(k, v.class.new(self, parent_obj, nil))
      end
    end

    @extra = { }
    @groups = { }
    @name = name
    @parent = parent
    @resolve_parent = resolve_parent
    @owner_module = mod
    raise "Invalid owner" if !@owner_module
    if (parent == nil)
      @source = []
      @exclude_sources = []
      @include_paths = []
      @dependencies = []
      @flags = []
      @libraries = []

      @debug_generate = false
    end
  end

  def path
    p = "[#{@name}]"
    if (@parent)
      p = @parent.path + p
    end
    return p
  end

  def root
    return @owner_module.root
  end

  def when(cond_input)
    cond = Condition.wrap(cond_input)
    grp = @groups[cond.to_s]
    if (grp == nil)
      grp = Group.new(@registry, @owner_module, cond.to_s, self, self)
      grp.condition = cond
      @groups[cond.to_s] = grp
      yield(grp) if block_given?
    end

    return grp
  end

  def group(name)
    raise "Invalid group name" unless name.is_a?(Symbol)

    grp = lookup_group(name)
    if (grp == nil)
      parent_group = @parent ? @parent.lookup_group(name) : nil
      grp = Group.new(@registry, @owner_module, name, parent_group, nil)

      @helpers.each do |k, v|
        if (!grp.first_helper(k))
          grp.add_helper(k, v.class.new(grp, parent_group, nil))
        end
      end

      @groups[name] = grp
      yield(grp) if block_given?
    end

    return grp
  end

  def lookup_group(name)
    return @groups[name]
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

  def add_helper(name, hlp)
    raise "Invalid duplicate helper #{name}" unless !@helpers.include?(name)
    @helpers[name] = hlp
  end

  def first_helper(id)
    val = @helpers[id]
    if (@parent && val == nil)
      return @parent.first_helper(id)
    end
    return val
  end

  def resolve_dependencies(resolving = [])
    if (@dependencies == nil)
      return
    end

    raise "Cyclic dependency detected when resolving #{resolving.map{|g| g.name }}" if resolving.include?(self)
    resolving << self

    @groups.each{|k, g| g.resolve_dependencies(resolving) }

    @dependencies.each do |x|
      if (!@registry.has_module(x))
        require "modules/#{x.to_s}"
      end

      mod = @registry.lookup_module(x)

      add_dependency(mod)
    end
  end

  def config
    return owner_module.config
  end

private
  def add_dependency(mod)
    raise "Invalid dependency #{x}, doesn't exist" unless mod
    raise "Invalid dependency #{x}, cannot depend on self" if mod.name.to_s == name

    grp = mod.lookup_group(:export)
    if (!grp)
      return
    end

    @groups[mod] = grp
    @resolved_dependencies = mod
  end
end

end
end