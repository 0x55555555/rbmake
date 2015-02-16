
if(MSVC)
  set(RBMAKE_WARN_ALL "/W4")

else()
  set(RBMAKE_WARN_ALL "-Wall")
  
endif()

set(RBMAKE_DEBUG CMAKE_BUILD_TYPE EQUAL "DEBUG")

if(WIN32)
  set(RBMAKE_PLATFORM "win")
elseif(APPLE)
  set(RBMAKE_PLATFORM "osx")
  set(RBMAKE_GCCLIKE true)
elseif(UNIX)
  set(RBMAKE_PLATFORM "unix")
  set(RBMAKE_GCCLIKE true)
else()
  message( FATAL_ERROR "Invalid platform." )
endif()
