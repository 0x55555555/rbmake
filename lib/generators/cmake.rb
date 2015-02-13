require 'pathname'
require 'module'

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

def generate_group(output, conf, root, grp, depth)
  mod = grp.is_a?(RbMake::Impl::Module)
  d = "  " * depth
  puts "#{d}GENERATE GROUP #{grp.name}------------------"
  d += "  "
  puts "#{d}CONDITION(#{grp.condition ? grp.condition.name : ""})"
  puts "#{d}LIBRARIES(#{prop(mod, grp, :libraries)})"
  puts "#{d}DEPENDENCIES(#{prop(mod, grp, :dependencies)})"
  puts "#{d}INCLUDE_PATHS(#{prop(mod, grp, :include_paths)})"

  specified_src = prop(mod, grp, :sources)
  if (specified_src)
    src = specified_src.map do |g| 
      path = root + "/" + g
      if (!File.exist?(path))
        next Dir[path]
      end

      next path
    end

    neat_src = src.flatten
    puts "#{d}SOURCE(#{neat_src.to_a[0..4]})"
    output.puts("set(SOURCE ${SOURCE} #{neat_src.join("\n  ")})")
  end

  cpp = grp.first_helper(:cpp)
  puts "#{d}DEFINES(#{prop(mod, cpp, :defines)}"
  puts "#{d}FLAGS(#{prop(mod, cpp, :flags)})"
  puts "#{d}OSX_VER(#{cpp.minimum_osx_version})"
  puts

  grps = grp.is_a?(RbMake::Impl::Module) ? grp.flat_groups : grp.groups.values
  grps.each do |v|
    generate_group(output, conf, root, v, depth + 1)
  end
end

class OutputFormatter
  attr_reader :output

  def initialize()
    @output = ""
  end

  def puts(s)
    @output << s << "\n"
  end
end

def generate(conf, reg)
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

    output = OutputFormatter.new
    output.puts("cmake_minimum_required(VERSION 3.1)")
    output.puts("project(TEST)")

    generate_group(output, conf, v.root, v, 0)

    type = TargetTypeMap[v.type]
    raise "Invalid target type #{v.type}" unless type

    output.puts("add_library (#{v.name} #{type} ${SOURCE})")
    output.puts("SET_TARGET_PROPERTIES(#{v.name} PROPERTIES LINKER_LANGUAGE CXX)")
    #target_include_directories (#{name} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

    File.open('CMakeLists.txt', 'w') do |f|
      f.write(output.output)
    end

    type = TypeMap[conf.type]
    raise "Invalid type #{conf.type}" unless type

    puts `cmake . -G #{type}`
  end
end