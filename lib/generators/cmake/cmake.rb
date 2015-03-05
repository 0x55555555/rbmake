require 'pathname'
require 'module'

$:.unshift File.dirname(__FILE__)

RbMakeCMakeLocation = File.dirname(__FILE__)

TypeMap = {
  :xcode => 'Xcode',
  :make => '"Unix Makefiles"',
}

TargetTypeMap = {
  :dummy => nil,
  :test => { :primary => 'add_executable' },
  :application => { :primary => 'add_executable' },
  :dynamic_library => { :primary => 'add_library', :secondary => 'SHARED' },
  :static_library => { :primary => 'add_library', :secondary => 'STATIC' },
  :module => { :primary => 'add_library', :secondary => 'MODULE' },
}

BuildVariants = {
  :debug => "Debug",
  :release => "Release",
}

def prop(obj, prop)
  raise "Invalid object" unless obj
  this = obj.method(prop).call

  if (block_given?)
    this = yield this
  end

  if (!this)
    return nil
  end

  if (obj.resolve_parent)
    parent = obj.resolve_parent.method(prop).call
    if (!parent)
      return nil
    end

    if (block_given?)
      parent = yield parent
    end

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
    output.append_to_variable(:compiler_options, "-std=c++1y")
  when :cpp11
    output.append_to_variable(:compiler_options, "-std=c++11")

  when :warn_as_error
    output.append_to_variable(:compiler_options, "${RBMAKE_WARN_ALL}")

  else
    output.append_to_variable(:compiler_options, "#{f}")
  end
end

def debug_variable(hdr, id, val)
  if (val == nil || (val.is_a?(Array) && val.length == 0))
    return
  end
  puts "#{hdr}#{id}(#{val})"
end

def expand_sources(root, src)
  if (!src)
    return []
  end

  neat_src = src.map do |g| 
    path = root + "/" + g
    if (!File.exist?(path))
      glob = Dir[path]
      raise "Invalid dir glob '#{path}' - no source files found" unless glob.length > 0
      next glob
    end

    next path
  end

  files = neat_src.flatten
  return files.select{ |f| !Dir.exist?(f) }
end

def expand_include_path(root, paths)
  paths.map do |path|
    if (path[0] == '$' || Pathname.new(path).absolute?)
      next path
    end

    next "#{root}/#{path}"
  end
end

def generate_group(generated, output, conf, root, root_mod, grp, depth)
  if (generated.include?(grp))
    return
  end
  generated << grp

  mod = grp.is_a?(RbMake::Impl::Module)
  cpp = grp.first_helper(:cpp)
  if (grp.name == :export && grp == root_mod.lookup_group(:export))
    return
  end

  include_paths = prop(grp, :include_paths) do |i|
    next expand_include_path(grp.root, i)
  end

  values = {
    :condition => grp.condition,
    :dependencies => prop(grp, :dependencies),
    :sources => prop(grp, :sources),
    :exclude_sources => prop(grp, :exclude_sources),
    :libraries => prop(grp, :libraries),
    :include_paths => include_paths,
  }
  if (cpp)
    values[:defines] = prop(cpp, :defines)
    values[:flags] = prop(cpp, :flags)
    values[:osx_version] = cpp.minimum_osx_version
  end

  output.if_condition(grp.condition) do
    if (root_mod.debug_generate)
      d = "  " * depth
      gen_line = d + "Generate #{grp.path}"
      gen_line += '-' * [0, (80 - gen_line.length)].max
      puts gen_line
      d += "  "

      if (cpp)
        puts "#{d}  with cpp #{cpp.path}"
      end

      if (grp.resolve_parent)
        puts "#{d}  relative to #{grp.resolve_parent.path}"
      end

      values.each{ |k, v| debug_variable(d, k, v) }
      puts
    end

    output.puts(grp.extra[:cmake])

    if (values[:sources] && values[:sources].length > 0)
      neat_src = expand_sources(root, values[:sources])
      exclude = expand_sources(root, values[:exclude_sources])

      output.append_to_variable(:sources, (neat_src - exclude).join("\n  "))
    end

    if (values[:libraries] && values[:libraries].length > 0)
      output.append_to_variable(:libraries, values[:libraries].join(" "))
    end

    if (values[:include_paths] && values[:include_paths].length > 0)
      output.append_to_variable(:private_includes, values[:include_paths].join(" "))
    end


    if (cpp)
      if (values[:defines] && values[:defines].length > 0)
        output.append_to_variable(:definitions, " #{values[:defines].join(" ")}")
      end

      if (values[:flags] && values[:flags].length > 0)
        values[:flags].map do |f|
          generate_flag(output, f)
        end
      end

      if (values[:osx_version])
        osx_ver = " -mmacosx-version-min=#{values[:osx_version]}"
        output.append_to_variable(:compiler_options, osx_ver)
      end
    end

    grps = grp.is_a?(RbMake::Impl::Module) ? grp.flat_groups : grp.groups.values
    grps.each do |v|
      generate_group(generated, output, conf, root, root_mod, v, depth + 1)
    end
  end
end

class OutputFormatter
  attr_reader :output
  attr_accessor :variables

  def initialize()
    @variables = nil
    @output = ""
    @tabs = 0
    @properties = { }
  end

  def puts(s)
    @output << '  ' * @tabs << s.to_s << "\n"
  end

  def append_to_variable(var, append)
    var_name = @variables[var]
    raise "Invalid variable #{var}" unless var_name
    puts("list(APPEND #{var_name} #{append})\n")
  end

  def puts_set_properties()
    @properties.each do |p, v|
      puts("set_property(TARGET #{@variables[:name]} PROPERTY #{p} #{v})\n")
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

def generate_cmake(project_name, conf, reg, input_type, variant)
  puts "Generating cmake files"

  output = OutputFormatter.new
  output.puts("cmake_minimum_required(VERSION 3.1)\n")
  output.puts("enable_testing()\n")
  output.puts("project(#{project_name})\n")
  output.puts("set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} #{RbMakeCMakeLocation})")
  output.puts("find_package(rbmake-utils)\n")


  reg.modules.values.select{ |l| l.generate }.each do |v|

    raise "Unable to generate modules" if v.class == RbMake::Impl::Module

    if (v.debug_generate)
      puts "Generate #{v.name}"
      puts "ROOT(#{v.root})"
      puts "TARGET #{v.name}"
      puts "TYPE(#{v.type})"
    end

    cpp = v.first_helper(:cpp)
    if (!cpp)
      raise "Cannot generate non-cpp project"
    end

    generated = Set.new
    output.variables = {
      :name => v.name,
      :sources => "#{v.name}_sources",
      :private_includes => "#{v.name}_private_includes",
      :definitions => "#{v.name}_definitions",
      :libraries => "#{v.name}_libraries",
      :compiler_options => "#{v.name}_compiler_options",
    }

    clean_root = v.root.gsub(/[\\\/]+/, '/')

    generate_group(generated, output, conf, clean_root, v, v, 0)

    type = TargetTypeMap[v.type]
    raise "Invalid target type #{v.type}" unless type

    vars = output.variables
    output.puts(%{
#{type[:primary]} (#{vars[:name]} 
  #{type[:secondary]}
    ${#{vars[:sources]}}
  )})
    if (v.type == :test)
      output.puts("add_test(#{vars[:name]} #{vars[:name]})")
    end

    output.puts(%{
make_source_groups("#{clean_root}" "${#{vars[:sources]}}")})
    output.puts(%{
set_property(TARGET #{vars[:name]} PROPERTY 
  LINKER_LANGUAGE CXX
  )})
    output.puts(%{
set_property(TARGET #{vars[:name]} PROPERTY 
  COMPILE_OPTIONS ${#{vars[:compiler_options]}}
  )})
    output.puts(%{
if (DEFINED #{vars[:definitions]})
  set_property(TARGET #{vars[:name]} PROPERTY 
    COMPILE_DEFINITIONS ${#{vars[:definitions]}}
    )
endif()})
    output.puts(%{
target_include_directories (#{vars[:name]}
  PRIVATE
    ${#{vars[:private_includes]}}
  )})
    output.puts(%{
target_link_libraries (#{vars[:name]}
  LINK_PRIVATE
    ${#{vars[:libraries]}}
  )})
    output.puts_set_properties()
  end


  File.open('CMakeLists.txt', 'w') do |f|
    f.write(output.output)
  end

  type = TypeMap[input_type]
  raise "Invalid type #{input_type}" unless type

  out = `cmake . -G #{type} -DCMAKE_BUILD_TYPE=#{BuildVariants[variant]}`
  if ($?.exitstatus != 0)
    puts "Error running cmake"
    puts out
  end
end