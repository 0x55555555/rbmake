
module RbMake
module Impl

class Condition
  def self.wrap(val)
    if (val.kind_of?(Condition))
      return val
    end

    return Condition.new(val, val)
  end

  attr_reader :test, :value

  def initialize(test, value)
    @test = test
    @value = value
  end

  def to_s
    return "#{@test} = #{@value}"
  end
end

end
end