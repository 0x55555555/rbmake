require 'pathname'
require 'module'

RbMakeCMakeLocation = File.dirname(__FILE__)

TypeMap = {
  :xcode => 'Xcode'
}

TargetTypeMap = {
  :dynamic_library => 'SHARED',
  :static_library => 'STATIC',
  :module => 'MODULE',
}

def prop(mod, obj, prop)
  this = obj.method(prop).call

  if (!mod)
    parent = obj.parent.method(prop).call
    return this - parent
  end

  return this
end

def format_condition(c)
  if (c.test == true)
    return nil
  end

  type = "EQUAL"
  if (c.value.is_a?(String) || c.value.is_a?(Symbol))
    type = "STREQUAL"
  end

  return "${RBMAKE_#{c.test.upcase}} #{type} #{c.value}"
end

def generate_flag(output, f)
  case f
  when :cpp14
    output.puts("if(DEFINED RBMAKE_GCCLIKE)\n  add_definitions(-std=c++1y)\nendif()") 
  when :cpp11
    output.puts("if(DEFINED RBMAKE_GCCLIKE)\n  add_definitions(-std=c++11)\nendif()") 

  when :warn_as_error
    output.append_to_variable(:compiler_options, "${RBMAKE_WARN_ALL}")

  else
    output.append_to_variable(:compiler_options, "\" #{f}\"")
  end
end

def debug_variable(hdr, id, val)
  if (val == nil || (val.is_a?(Array) && val.length == 0))
    return
  end
  puts "#{hdr}#{id}(#{val})"
end

def generate_group(output, conf, root, grp, depth)
  mod = grp.is_a?(RbMake::Impl::Module)
  cpp = grp.first_helper(:cpp)

  values = {
    :condition => grp.condition,
    :dependencies => prop(mod, grp, :dependencies),
    :sources => prop(mod, grp, :sources),
    :libraries => prop(mod, grp, :libraries),
    :include_paths => prop(mod, grp, :include_paths),
    :defines => prop(mod, cpp, :defines),
    :flags => prop(mod, cpp, :flags),
    :osx_version => cpp.minimum_osx_version,
  }

  output.if_condition(grp.condition) do
    if (grp.debug_generate)
      d = "  " * depth
      gen_line = d + "Generate #{grp.path} "
      gen_line += '-' * [0, (80 - gen_line.length)].max
      puts gen_line
      d += "  "

      values.each{ |k, v| debug_variable(d, k, v) }
      puts
    end

    if (values[:sources].length > 0)
      src = values[:sources].map do |g| 
        path = root + "/" + g
        if (!File.exist?(path))
          glob = Dir[path]
          raise "Invalid dir glob '#{path}' - no source files found" unless glob.length > 0
          next glob
        end

        next path
      end

      neat_src = src.flatten
      output.append_to_variable(:sources, neat_src.join("\n  "))
    end

    if (values[:libraries].length > 0)
      output.append_to_variable(:libraries, values[:libraries].join(" "))
    end

    if (values[:include_paths].length > 0)
      output.append_to_variable(:private_includes, values[:include_paths].map{ |i| "#{grp.root}/#{i}" }.join(" "))
    end

    if (values[:defines].length > 0)
      output.append_to_variable(:definitions, "\" #{values[:defines].join(" ")}\"")
    end

    if (values[:flags].length > 0)
      values[:flags].map do |f|
        generate_flag(output, f)
      end
    end

    if (values[:osx_version])
      osx_ver = "\" -mmacosx-version-min=#{values[:osx_version]}\""
      output.append_to_variable(:compiler_options, osx_ver)
    end

    grps = grp.is_a?(RbMake::Impl::Module) ? grp.flat_groups : grp.groups.values
    grps.each do |v|
      generate_group(output, conf, root, v, depth + 1)
    end
  end
end

class OutputFormatter
  attr_reader :output

  def initialize(vars)
    @vars = vars
    @output = ""
    @tabs = 0
    @properties = { }
  end

  def puts(s)
    @output << '  ' * @tabs << s.to_s << "\n"
  end

  def append_to_variable(var, append)
    var_name = @vars[var]
    raise "Invalid variable #{var}" unless var_name
    puts("set(#{var_name} ${#{var_name}} #{append})")
  end

  def puts_set_properties()
    @properties.each do |p, v|
      puts("set_property(TARGET #{@vars[:name]} PROPERTY #{p} #{v})")
    end
  end

  def set_target_property(prop, val)
    @properties[prop] = val
  end

  def if_condition(cond)
    formatted = cond != nil ? format_condition(cond) : nil
    if (!formatted)
      yield
      return
    end

    puts "if(#{formatted})"
    @tabs += 1
    yield
    @tabs -= 1
    puts "endif()"
  end
end

def generate(project_name, conf, reg)
  puts "Generating cod"
  reg.modules.values.select{ |l| l.generate }.each do |v|
    puts "Generate #{v.name}"

    raise "Unable to generate modules" if v.class == RbMake::Impl::Module

    header = 

    puts "ROOT(#{v.root})"
    puts "TARGET #{v.name}"
    puts "TYPE(#{v.type})"

    cpp = v.first_helper(:cpp)
    if (!cpp)
      raise "Cannot generate non-cpp project"
    end

    vars = {
      :name => v.name,
      :sources => "#{v.name}_sources",
      :public_includes => "#{v.name}_public_includes",
      :private_includes => "#{v.name}_private_includes",
      :definitions => "#{v.name}_definitions",
      :libraries => "#{v.name}_libraries",
      :compiler_options => "#{v.name}_compiler_options",
    }

    output = OutputFormatter.new(vars)
    output.puts("cmake_minimum_required(VERSION 3.1)")
    output.puts("project(#{project_name})")
    output.puts("find_package(rbmake-utils PATHS #{RbMakeCMakeLocation})")

    generate_group(output, conf, v.root, v, 0)

    type = TargetTypeMap[v.type]
    raise "Invalid target type #{v.type}" unless type

    output.puts("add_library (#{vars[:name]} #{type} ${#{vars[:sources]}})")
    output.puts("SET_TARGET_PROPERTIES(#{vars[:name]} PROPERTIES LINKER_LANGUAGE CXX)")
    output.puts("SET_TARGET_PROPERTIES(#{vars[:name]} PROPERTIES COMPILE_OPTIONS ${#{vars[:compiler_options]}})")
    output.puts("if (DEFINED #{vars[:definitions]})\n  SET_TARGET_PROPERTIES(#{vars[:name]} PROPERTIES COMPILE_DEFINITIONS ${#{vars[:definitions]}})\nendif()")
    output.puts("target_include_directories (#{vars[:name]} PUBLIC ${#{vars[:public_includes]}} PRIVATE ${#{vars[:private_includes]}})")
    output.puts_set_properties()


    File.open('CMakeLists.txt', 'w') do |f|
      f.write(output.output)
    end

    type = TypeMap[conf.type]
    raise "Invalid type #{conf.type}" unless type

    puts `cmake . -G #{type}`
  end
end