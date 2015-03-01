
module RbMake
module Impl

class CppHelper

  attr_reader :name, :parent, :resolve_parent

  extend Utils
  attr_forwarder :defines, :flags, :minimum_osx_version, :file_patterns

  def initialize(owner, parent, resolve_parent)
    @owner = owner
    @name = :cpp
    @parent = parent
    @resolve_parent = resolve_parent

    if (parent == nil)
      @defines = []
      @flags = []
      @file_patterns = [ 'c', 'cpp', 'h', 'hpp' ]
    end
  end

  def path
    name = "[#{@owner.path}-#{@name}]"
    if (@parent)
      return "#{@parent.path}#{name}"
    end
    return name
  end
end

end
end
