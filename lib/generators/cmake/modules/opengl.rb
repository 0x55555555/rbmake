require 'modules/global'

RbMake.library(:opengl, :global) do |l|
  l.type = :dummy
  l.generate = false

  l.export do |l|
    l.extra[:cmake] = 'find_package(OpenGL REQUIRED)'
    l.include_paths = [ '${OPENGL_INCLUDE_DIR}' ]
    l.libraries = [ '${OPENGL_LIBRARIES}' ]
  end
end