require 'pathname'

module RbMake
module Impl

class Config
  attr_reader :build_root, :type

  Types = [
    :xcode,
  ]

  def initialize(build_root, type)
    @build_root = File.expand_path(build_root)
    @type = type
    puts "Source build_root set to #{@build_root}"
  end

  def debug(on=true)
    return Condition.new("debug=#{on}")
  end

  def platform(id)
    return Condition.new("platform=#{id}")
  end
end

end
end