
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

function(make_source_groups PREFIX SOURCES)
  foreach(FILE ${SOURCES}) 
    get_filename_component(GROUP "${FILE}" PATH)

    # skip src or include and changes /'s to \\'s
    # string(REGEX REPLACE "(\\./)?(src|include)/?" "" GROUP "${GROUP}")
    string(REPLACE ${PREFIX} "" GROUP "${GROUP}")
    string(REPLACE "/" "\\" GROUP "${GROUP}")

    source_group("${GROUP}" FILES "${FILE}")
  endforeach()
endfunction()