require 'pathname'
require 'group'

module RbMake
module Impl

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

    root = @registry.config.build_root

    @root = Pathname.new(File.dirname(file))
      .relative_path_from(Pathname.new(root))
      .cleanpath.to_s

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

end
end