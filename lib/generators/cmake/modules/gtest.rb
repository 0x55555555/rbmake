require 'modules/global'

RbMake.library(:gtest, :global) do |l|
  l.type = :dummy
  l.generate = false

  l.export do |l|
    l.extra[:cmake] = 'find_package(GTest REQUIRED)'
    l.include_paths = [ '${GTEST_INCLUDE_DIRS}' ]
    l.libraries = [ '${GTEST_LIBRARIES}', '${GTEST_MAIN_LIBRARIES}', 'pthread' ]
  end
end