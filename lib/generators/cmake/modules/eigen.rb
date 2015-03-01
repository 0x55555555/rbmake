require 'modules/global'

RbMake.library(:eigen, :global) do |l|
  l.type = :dummy
  l.generate = false

  module_path = '/usr/local/Cellar/eigen/3.2.3/share/cmake/Modules'

  l.export do |l|
    l.extra[:cmake] = %{
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} #{module_path})
find_package(Eigen3 REQUIRED)}
    l.include_paths = [ '${Eigen3_INCLUDE_DIRS}' ]
  end
end