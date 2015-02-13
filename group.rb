relative 'condition'
relative 'utils'

module RbMake
module Impl

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

end
end