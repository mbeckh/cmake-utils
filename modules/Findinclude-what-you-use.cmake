# Copyright 2021-2022 Michael Beckh
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# Find module for include-what-you-use.
# Adds a single function: include_what_you_use(<[ ALL | <target> ...]).
# Set variable include-what-you-use_ROOT if include-what-you-use is not found automatically.
#

cmake_policy(VERSION 3.25)
include(CMakeFindDependencyMacro)
include(FindPackageHandleStandardArgs)

function(z_include_what_you_use_get_version)
    execute_process(COMMAND "${include-what-you-use_EXE}" --version OUTPUT_VARIABLE out)
    if(out MATCHES "include-what-you-use ([0-9.]+)")
        set(include-what-you-use_VERSION "${CMAKE_MATCH_1}" PARENT_SCOPE)
    endif()
endfunction()

find_program(include-what-you-use_EXE include-what-you-use)
if(include-what-you-use_EXE)
    cmake_path(GET include-what-you-use_EXE PARENT_PATH include-what-you-use_ROOT)
    find_file(include-what-you-use_IMP_STDLIB stl.c.headers.imp HINTS "${include-what-you-use_ROOT}" PATH_SUFFIXES include-what-you-use)
    z_include_what_you_use_get_version()

    if(include-what-you-use_VERSION)
        find_dependency(ClangTools)
    endif()
endif()
mark_as_advanced(include-what-you-use_EXE include-what-you-use_ROOT include-what-you-use_IMP_STDLIB)
find_package_handle_standard_args(include-what-you-use
                                  REQUIRED_VARS include-what-you-use_EXE include-what-you-use_IMP_STDLIB ClangTools_FOUND
                                  VERSION_VAR include-what-you-use_VERSION
                                  HANDLE_VERSION_RANGE)

if(NOT include-what-you-use_FOUND)
    return()
endif()

include_guard(GLOBAL)

function(include_what_you_use #[[ <target> ... ]])
    clang_tools_run(iwyu NAME include-what-you-use
                    TARGETS ${ARGV}
                    MAP_INCLUDES
                    MAP_SOURCES
                    MAP_COMMAND "@CMAKE_COMMAND@"
                                -D "include-what-you-use_EXE=@include-what-you-use_EXE@"
                                -D "include-what-you-use_MAPPING_FILES=@include-what-you-use_IMP_STDLIB@"
                                -D "COMPILE_COMMANDS_PATH=@target_compile_commands_path@"
                                -D "FILES=@files@"
                                -D "OUTPUT=@output@"
                                -P "@CMAKE_CURRENT_FUNCTION_LIST_DIR@/clang-tools/run-include-what-you-use.cmake"
                    MAP_DEPENDS "@CMAKE_CURRENT_FUNCTION_LIST_DIR@/clang-tools/run-include-what-you-use.cmake"
                                "@include-what-you-use_EXE@"
                                "@include-what-you-use_IMP_STDLIB@"
                                "@CMAKE_CURRENT_FUNCTION_LIST_DIR@/clang-tools/msvc.imp"
                                "@target_compile_commands_path@.sources")
endfunction()
