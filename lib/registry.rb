
module RbMake
module Impl

class Registry
  
  attr_reader :config, :modules

  def initialize(config)
    @modules = { }
    @helpers = { }
    @config = config
  end

  def has_module(id)
    return @modules.include?(id)
  end

  def lookup_module(id)
    if (id == nil)
      return nil
    end

    obj = @modules[id]
    raise "Invalid module id #{id}" unless obj

    return obj
  end

  def register_module(mod)
    puts "Registering Module #{mod.name}"
    if @modules.include?(mod.name)
      a = @modules[mod.name].definition[:file]
      b = mod.definition[:file]
      raise "Module #{mod.name} re-registered, at both:\n#{a}\nand\n#{b}" 
    end
    @modules[mod.name] = mod
  end

  def lookup_helper(id)
    if (id == nil)
      return nil
    end

    obj = @helpers[id]
    raise "Invalid helper id #{id}" unless obj

    return obj
  end

  def register_helper(hlp)
    puts "Registering Helper #{hlp.name}"
    raise "Helper #{hlp.name} re-registered" unless !@helpers.include?(hlp.name)
    @helpers[hlp.name] = hlp
  end
end

end
end