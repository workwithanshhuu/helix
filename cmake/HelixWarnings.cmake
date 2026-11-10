# helix_set_warnings(<target>)
#
# Applies the project-wide warning set to a target. Every Helix C++ target must
# call this (see SPEC.md §1, "Code rules"). Warnings are errors unless
# HELIX_WARNINGS_AS_ERRORS=OFF, which is only meant for experimenting locally.

function(helix_set_warnings target)
  if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
    target_compile_options(${target} PRIVATE
      -Wall
      -Wextra
      -Wpedantic
      -Wshadow
      -Wconversion
      -Wsign-conversion
      -Wnon-virtual-dtor
      -Wold-style-cast
      -Wcast-align
      -Woverloaded-virtual
      -Wnull-dereference
      -Wdouble-promotion
      -Wformat=2
      -Wimplicit-fallthrough)
    if(HELIX_WARNINGS_AS_ERRORS)
      target_compile_options(${target} PRIVATE -Werror)
    endif()
  endif()
endfunction()
