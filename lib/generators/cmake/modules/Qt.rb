require 'modules/global'

QtModules = [ :Core, :Gui, :OpenGL ]

QtModules.each do |name|
  name_sym = ('Qt' + name.to_s).to_sym
  name = 'Qt5' + name.to_s
  RbMake.library(name_sym, :global) do |l|
    l.extend_with(:cpp)

    l.type = :dummy
    l.generate = false

    l.export do |l|
      l.extra[:cmake] = %{
set(CMAKE_AUTOMOC ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)
FIND_PACKAGE(#{name} REQUIRED)
}
      l.libraries = [ "${#{name}_LIBRARIES}" ]
      l.include_paths = [ "${#{name}_INCLUDE_DIRS}" ]
      l.cpp.flags = [ "${#{name}_EXECUTABLE_COMPILE_FLAGS}" ]
    end
  end
end
