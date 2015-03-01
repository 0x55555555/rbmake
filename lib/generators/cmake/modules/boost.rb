require 'modules/global'

RbMake.library(:boost, :global) do |l|
  l.type = :dummy
  l.generate = false

  l.export do |l|
    l.extra[:cmake] = 'find_package(Boost REQUIRED)'
    l.libraries = [ '${Boost_LIBRARIES}' ]
    l.include_paths = [ '${Boost_INCLUDE_DIRS}' ]
  end
end