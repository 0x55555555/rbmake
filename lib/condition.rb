
module RbMake
module Impl

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

end
end