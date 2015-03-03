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
    super(registry, self, name, parent, nil)

    @root = ''
    @generate = false
    @definition = nil
  end

  def build(loc, block)
    loc_splits = Utils::caller_file(1)
    file = loc_splits[0]
    @definition = { :file => file, :line => loc_splits[1].to_i }

    root = @registry.config.build_root

    @root = Pathname.new(File.dirname(file))
      .relative_path_from(Pathname.new(root))
      .cleanpath.to_s + '/'

    @registry.register_module(self)
    block.call(self, parent)

    resolve_dependencies()

    if (type != :dummy && generate)
      export = group(:export)
      export.libraries << name
    end
  end

  def extend_with(helper_id)
    helper = @registry.lookup_helper(helper_id)
    if (@parent)
      parent_helper = @parent.first_helper(helper_id)
    end
    add_helper(helper.name, helper.class.new(self, parent_helper, parent_helper))
  end

  def config
    return @registry.config
  end

  def export
    return group(:export) do |l|
      yield l
    end
  end
end

end
end