
module RbMake
module Impl
module Utils

  def self.caller_file(plus=0)
    return caller[plus+1].split(":")[0..1]
  end

  def attr_forwarder(*args)
    args.each do |arg|
      
      var_name = "@#{arg}"

      # Here's the getter
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

  def self.find_best_input(input_file)
    if (input_file == nil || (File.exist?(input_file) && Dir.exist?(input_file)))
      path = '.'
      if (input_file)
        path = input_file
      end

      expanded = File.expand_path(path)

      name =  File.basename(expanded)
      input_file = expanded + "/#{name}.rb"
    end
    raise "Invalid input file #{input_file}" unless File.exist?(input_file)
    return input_file
  end

end
end
end