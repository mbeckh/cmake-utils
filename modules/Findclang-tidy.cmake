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
    cmake_path(GET clang-tidy_EXE PARENT_PATH clang-tidy_ROOT)
    find_program(clang-tidy_PY NAMES run-clang-tidy run-clang-tidy.py HINTS "${clang-tidy_ROOT}")
    if(clang-tidy_PY)
        z_clang_tidy_get_version()
        if(clang-tidy_VERSION)
            find_dependency(ClangTools)
            find_dependency(Python COMPONENTS Interpreter)
        endif()
    endif()
endif()
mark_as_advanced(clang-tidy_EXE clang-tidy_PY clang-tidy_ROOT)
find_package_handle_standard_args(clang-tidy
                                  REQUIRED_VARS clang-tidy_EXE clang-tidy_PY ClangTools_FOUND Python_FOUND
                                  VERSION_VAR clang-tidy_VERSION
                                  HANDLE_VERSION_RANGE)

if(NOT clang-tidy_FOUND)
    return()
endif()

include_guard(GLOBAL)

function(z_clang_tidy_unity target #[[ OUTPUT <output> [ DEPENDS <dependencies> ] ]])
    cmake_parse_arguments(PARSE_ARGV 1 arg "" "OUTPUT" "DEPENDS")
    if(NOT arg_OUTPUT)
        message(FATAL_ERROR "OUTPUT is missing for z_clang_tidy_unity")
    endif()

    set_property(TARGET "${target}" APPEND_STRING PROPERTY UNITY_BUILD_CODE_BEFORE_INCLUDE "// NOLINTNEXTLINE(bugprone-suspicious-include)")

    get_target_property(source_dir "${target}" SOURCE_DIR)
    get_target_property(binary_dir "${target}" BINARY_DIR)

    unset(depends)
    cmake_path(RELATIVE_PATH source_dir BASE_DIRECTORY "${PROJECT_SOURCE_DIR}" OUTPUT_VARIABLE relative)
    while(relative)
        set(src "${PROJECT_SOURCE_DIR}/${relative}/.clang-tidy")
        if(EXISTS "${src}")
            if(depends)
                message(STATUS "clang-tidy-${target}: Ignoring non-root and non-leaf config: ${relative}/.clang-tidy")
            else()
                set(dst "${binary_dir}/CMakeFiles/${target}.dir/.clang-tidy")
                add_custom_command(OUTPUT "${dst}"
                                   COMMAND "${CMAKE_COMMAND}" -E copy "${src}" "${dst}"
                                   DEPENDS "${src}")
                list(APPEND depends "${dst}")
            endif()
        endif()
        cmake_path(GET relative PARENT_PATH relative)
    endwhile()

    # Make .clang-tidy config available to generated source files
    set(src "${PROJECT_SOURCE_DIR}/.clang-tidy")
    if(EXISTS "${src}")
        set(dst "${binary_dir}/CMakeFiles/.clang-tidy")
        add_custom_command(OUTPUT "${dst}"
                           COMMAND "${CMAKE_COMMAND}" -E copy "${src}" "${dst}"
                           DEPENDS "${src}")
        list(APPEND depends "${dst}")
    endif()

    add_custom_command(OUTPUT "${CMAKE_BINARY_DIR}/${arg_OUTPUT}"
                       COMMAND "${CMAKE_COMMAND}" -E rm -f "${CMAKE_BINARY_DIR}/.clang-tools/${arg_OUTPUT}"
                       COMMAND "${Python_EXECUTABLE}" "${clang-tidy_PY}"
                                "-clang-tidy-binary=${clang-tidy_EXE}"
                                -p "${CMAKE_BINARY_DIR}/.clang-tools/${target}"
                                "-extra-arg=-fmsc-version=${MSVC_VERSION}"
                                "-extra-arg=-Qunused-arguments"
                                "-header-filter=.*"
                                >> "${CMAKE_BINARY_DIR}/.clang-tools/${arg_OUTPUT}" || "${CMAKE_COMMAND}" -E true
                       COMMAND powershell -ExecutionPolicy Bypass
                               -File "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/clang-tools/remove-shell-colors.ps1"
                               "${CMAKE_BINARY_DIR}/.clang-tools/${arg_OUTPUT}"
                       COMMAND "${CMAKE_COMMAND}"
                               -D "TOOL=clang-tidy"
                               -D "OUTPUT=${CMAKE_BINARY_DIR}/${arg_OUTPUT}"
                               -D "FILES=${CMAKE_BINARY_DIR}/.clang-tools/${arg_OUTPUT}"
                               -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/clang-tools/cat.cmake"
                       DEPENDS ${arg_DEPENDS}
                               "clang-tools-compile_commands-${target}"
                               "${depends}"
                               "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/clang-tools/remove-shell-colors.ps1"
                               "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/clang-tools/cat.cmake"
                       WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
                       COMMENT "clang-tidy (${target}): Analyzing"
                       JOB_POOL use_all_cpus
                       VERBATIM)
endfunction()

function(clang_tidy #[[ <target> ... ]])
    # Brute force for the time being, could be replaced by .d files per source
    file(GLOB_RECURSE depends LIST_DIRECTORIES NO .clang-tidy)
    clang_tools_run(clang-tidy
                    TARGETS ${ARGV}
                    UNITY z_clang_tidy_unity
                    MAP_COMMAND "@clang-tidy_EXE@"
                                -p ".clang-tools/@target@"
                                "--extra-arg=-fmsc-version=@MSVC_VERSION@"
                                "--extra-arg=-Qunused-arguments"
                                "--header-filter=.*"
                                @files@
                                > "@output@" || "@CMAKE_COMMAND@" -E true
                    MAP_DEPENDS ${depends}
                    MAP_EXTENSION tidy)
endfunction()
