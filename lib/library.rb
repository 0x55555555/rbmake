require 'module'

module RbMake
module Impl

class Library < Module
  def initialize(registry, name, parent)
    super
    @generate = true
  end
end

end
end