#
# Find module for include-what-you-use.
# Adds a single function: include_what_you_use(<[ ALL | <target> ...]).
# Set variable include-what-you-use_ROOT if include-what-you-use is not found automatically.
#
# MIT License, Copyright (c) 2021 Michael Beckh, see LICENSE
#

include(CMakeFindDependencyMacro)
include(FindPackageHandleStandardArgs)

find_dependency(ClangTools)
find_dependency(Python COMPONENTS Interpreter)

function(z_include_what_you_use_get_version)
    execute_process(COMMAND "${include-what-you-use_EXE}" --version OUTPUT_VARIABLE out)
    if(out MATCHES "include-what-you-use ([0-9.]+)")
        set(include-what-you-use_VERSION "${CMAKE_MATCH_1}" PARENT_SCOPE)
    endif()
endfunction()

find_program(include-what-you-use_EXE include-what-you-use)
cmake_path(GET include-what-you-use_EXE PARENT_PATH include-what-you-use_ROOT)
find_program(include-what-you-use_PY iwyu_tool.py HINTS "${include-what-you-use_ROOT}")
find_file(include-what-you-use_IMP_STDLIB stl.c.headers.imp HINTS "${include-what-you-use_ROOT}" PATH_SUFFIXES include-what-you-use)
mark_as_advanced(include-what-you-use_EXE include-what-you-use_PY include-what-you-use_IMP_STDLIB)
if(include-what-you-use_EXE)
    z_include_what_you_use_get_version()
endif()
find_package_handle_standard_args(include-what-you-use
                                  REQUIRED_VARS include-what-you-use_EXE include-what-you-use_PY include-what-you-use_IMP_STDLIB ClangTools_FOUND Python_FOUND
                                  VERSION_VAR include-what-you-use_VERSION
                                  HANDLE_VERSION_RANGE)

if(NOT include-what-you-use_FOUND)
    return()
endif()

include_guard(GLOBAL)

function(include_what_you_use #[[ <target> ... ]])
    clang_tools_run(iwyu NAME include-what-you-use
                    TARGETS ${ARGV}
                    MAP_COMMAND "@CMAKE_COMMAND@"
                                -D "MSVC_VERSION=@MSVC_VERSION@"
                                -D "Python_EXECUTABLE=@Python_EXECUTABLE@"
                                -D "include-what-you-use_PY=@include-what-you-use_PY@"
                                -D "include-what-you-use_MAPPING_FILES=@include-what-you-use_IMP_STDLIB@"
                                -D "TARGET=@target@"
                                -D "FILES=@files@"
                                -D "AUX_INCLUDES_FILES=@aux_includes_files@"
                                -D "OUTPUT=@output@"
                                -P "@CMAKE_CURRENT_FUNCTION_LIST_DIR@/clang-tools/run-include-what-you-use.cmake"
                    MAP_DEPENDS "@CMAKE_CURRENT_FUNCTION_LIST_DIR@/clang-tools/run-include-what-you-use.cmake"
                    MAP_EXTENSION iwyu
                    WITH_AUX_INCLUDE)
endfunction()