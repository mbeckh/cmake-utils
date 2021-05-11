# Copyright 2021 Michael Beckh
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
# Find module for clang-tidy.
# Adds a single function: clang_tidy([ ALL | <target> ...]).
# Set environment variable clang-tidy_ROOT if clang-tidy is not found automatically.
#

include(CMakeFindDependencyMacro)
include(FindPackageHandleStandardArgs)

function(z_clang_tidy_get_version)
    execute_process(COMMAND "${clang-tidy_EXE}" --version OUTPUT_VARIABLE out)
    if(out MATCHES "LLVM version ([0-9.]+)")
        set(clang-tidy_VERSION "${CMAKE_MATCH_1}" PARENT_SCOPE)
    endif()
endfunction()

find_program(clang-tidy_EXE clang-tidy)
mark_as_advanced(clang-tidy_EXE)
if(clang-tidy_EXE)
    z_clang_tidy_get_version()
    if(clang-tidy_VERSION)
      find_dependency(ClangTools)
    endif()
endif()
find_package_handle_standard_args(clang-tidy
                                  REQUIRED_VARS clang-tidy_EXE ClangTools_FOUND
                                  VERSION_VAR clang-tidy_VERSION
                                  HANDLE_VERSION_RANGE)

if(NOT clang-tidy_FOUND)
    return()
endif()

include_guard(GLOBAL)

function(clang_tidy #[[ <target> ... ]])
    # Brute force for the time beeing, could be replaced by .d files per source
    file(GLOB_RECURSE depends LIST_DIRECTORIES NO .clang-tidy)
    clang_tools_run(clang-tidy
                    TARGETS ${ARGV}
                    MAP_COMMAND "@CMAKE_COMMAND@"
                                -D "MSVC_VERSION=@MSVC_VERSION@"
                                -D "clang-tidy_EXE=@clang-tidy_EXE@"
                                -D "TARGET=@target@"
                                -D "INCLUDES=@includes@"
                                -D "FILES=@files@"
                                -D "AUX_INCLUDES_FILES=@aux_includes_files@"
                                -D "OUTPUT=@output@"
                                -P "@CMAKE_CURRENT_FUNCTION_LIST_DIR@/clang-tools/run-clang-tidy.cmake"
                    MAP_DEPENDS ${depends}
                                "@CMAKE_CURRENT_FUNCTION_LIST_DIR@/clang-tools/run-clang-tidy.cmake"
                    MAP_EXTENSION tidy
                    WITH_AUX_INCLUDE)
endfunction()
