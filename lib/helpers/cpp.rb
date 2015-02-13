
module RbMake
module Impl

class CppHelper

  attr_reader :name, :parent

  extend Utils
  attr_forwarder :defines, :flags, :minimum_osx_version, :file_patterns

  def initialize(parent)
    @name = :cpp
    @parent = parent

    @file_patterns = [ 'c', 'cpp', 'h', 'hpp' ]
  end

  def create(parent)
    return CppHelper.new(parent)
  end
end

end
end
