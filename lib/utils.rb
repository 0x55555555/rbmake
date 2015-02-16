
module RbMake
module Impl
module Utils

  def self.caller_file()
    return caller[1].split(":")[0..1]
  end

  def attr_forwarder(*args)
    args.each do |arg|
      
      var_name = "@#{arg}"

      #Here's the getter
      define_method(arg) do
        val = instance_variable_get(var_name)
        if (@parent && val == nil)
          val = @parent.method(arg).call()
          if (val.is_a?(Array))
            val = val.clone
          end
          instance_variable_set(var_name, val)
        end
        next val
      end
      
      define_method("#{arg}=".to_sym) do |val|
        instance_variable_set(var_name, val)
      end

    end
  end

end
end
end