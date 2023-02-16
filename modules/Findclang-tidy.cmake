# Copyright 2021-2023 Michael Beckh
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
    z_clang_tidy_get_version()
    if(clang-tidy_VERSION)
        find_dependency(ClangTools)
    endif()
endif()
mark_as_advanced(clang-tidy_EXE clang-tidy_ROOT)
find_package_handle_standard_args(clang-tidy
                                  REQUIRED_VARS clang-tidy_EXE ClangTools_FOUND
                                  VERSION_VAR clang-tidy_VERSION
                                  HANDLE_VERSION_RANGE)

if(NOT clang-tidy_FOUND)
    return()
endif()

include_guard(GLOBAL)

include("${CMAKE_CURRENT_LIST_DIR}/Regex.cmake")

function(z_clang_tidy_unity target #[[ OUTPUT <output> [ DEPENDS <dependencies> ] ]])
    cmake_parse_arguments(PARSE_ARGV 1 arg "" "OUTPUT" "DEPENDS")
    if(NOT arg_OUTPUT)
        message(FATAL_ERROR "OUTPUT is missing for z_clang_tidy_unity")
    endif()

    # Use sub-directory in case of multi-config
    get_property(is_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
    if(is_multi_config)
        set(config_subdir "$<CONFIG>/")
    else()
        unset(config_subdir)
    endif()

    set_property(TARGET "${target}" APPEND_STRING PROPERTY UNITY_BUILD_CODE_BEFORE_INCLUDE "// NOLINTNEXTLINE(bugprone-suspicious-include)")

    get_target_property(target_source_dir "${target}" SOURCE_DIR)
    cmake_path(IS_PREFIX PROJECT_SOURCE_DIR "${target_source_dir}" NORMALIZE is_prefix)
    if(NOT is_prefix)
        message(WARNING "Source directory of ${target} is not part of source tree ${PROJECT_SOURCE_DIR}")
        return()
    endif()

    get_target_property(target_binary_dir "${target}" BINARY_DIR)

    # Replace variables
    z_clang_tools_configure("${arg_DEPENDS}" arg_DEPENDS)

    # Get all source files
    get_target_property(target_sources "${target}" SOURCES)
    list(TRANSFORM target_sources GENEX_STRIP)

    set(extensions ${CMAKE_CXX_SOURCE_FILE_EXTENSIONS})
    list(APPEND extensions ${CMAKE_C_SOURCE_FILE_EXTENSIONS})

    regex_escape_pattern(extensions OUT extensions_pattern)
    list(JOIN extensions_pattern "|" extensions_pattern)

    list(FILTER target_sources INCLUDE REGEX "\.(${extensions_pattern})$")

    unset(parent_paths)
    foreach(source_path IN LISTS target_sources)
        cmake_path(NORMAL_PATH source_path)
        if(IS_ABSOLUTE "${source_path}")
            cmake_path(IS_PREFIX PROJECT_SOURCE_DIR "${source_path}" NORMALIZE is_prefix)
            if(is_prefix)
                cmake_path(RELATIVE_PATH source_path BASE_DIRECTORY "${PROJECT_SOURCE_DIR}")
            else()
                # skip files which are not part of the source tree
                continue()
            endif()
        elseif(NOT target_source_dir STREQUAL PROJECT_SOURCE_DIR)
            # convert path relative to target_source_dir to path relative to PROJECT_SOURCE_DIR
            cmake_path(ABSOLUTE_PATH source_path BASE_DIRECTORY "${target_source_dir}" NORMALIZE)
            cmake_path(RELATIVE_PATH source_path BASE_DIRECTORY "${PROJECT_SOURCE_DIR}")
        endif()

        cmake_path(GET source_path PARENT_PATH source_path)
        if(source_path)
            list(APPEND parent_paths "${source_path}")
        endif()
    endforeach()
    set(target_sources "${parent_paths}")

    # Get "deepest" directory of source file with .clang-tidy
    unset(clang_tidy_dir)
    while(target_sources)
        unset(parent_paths)
        foreach(source_path IN LISTS target_sources)
            if(EXISTS "${PROJECT_SOURCE_DIR}/${source_path}/.clang-tidy")
                if(NOT clang_tidy_dir)
                    set(clang_tidy_dir "${source_path}")
                elseif(NOT clang_tidy_dir STREQUAL source_path)
                    message(WARNING "Ignoring .clang-tidy in folder ${source_path}, overridden by ${clang_tidy_dir}")
                endif()
            endif()
            cmake_path(GET source_path PARENT_PATH source_path)
            if(source_path)
                list(APPEND parent_paths "${source_path}")
            endif()
        endforeach()
        list(REMOVE_DUPLICATES parent_paths)
        set(target_sources "${parent_paths}")
    endwhile()

    # Make .clang-tidy config from nested source folder available to generated source files
    unset(depends)
    set(dst "${target_binary_dir}/CMakeFiles/${target}.dir/.clang-tidy")
    if(clang_tidy_dir)
        message("${target}: Using .clang-tidy from ${clang_tidy_dir} for unity build")

        set(src "${PROJECT_SOURCE_DIR}/${clang_tidy_dir}/.clang-tidy")
        add_custom_command(OUTPUT "${dst}"
                           COMMAND "${CMAKE_COMMAND}" -E copy "${src}" "${dst}"
                           DEPENDS "${src}")
        list(APPEND depends "${dst}")
    else()
        file(REMOVE "${dst}")
    endif()

    # Make .clang-tidy config from root available to generated source files
    set(src "${PROJECT_SOURCE_DIR}/.clang-tidy")
    if(EXISTS "${src}")
        set(dst "${target_binary_dir}/CMakeFiles/.clang-tidy")
        add_custom_command(OUTPUT "${dst}"
                           COMMAND "${CMAKE_COMMAND}" -E copy "${src}" "${dst}"
                           DEPENDS "${src}")
        list(APPEND depends "${dst}")
    endif()

    add_custom_command(OUTPUT "${CMAKE_BINARY_DIR}/${arg_OUTPUT}"
                       COMMAND "${CMAKE_COMMAND}"
                               -D "clang-tidy_EXE=${clang-tidy_EXE}"
                               -D "COMPILE_COMMANDS_PATH=${CMAKE_BINARY_DIR}/.clang-tools/${target}/${config_subdir}"
                               -D "ninja_EXE=${CMAKE_MAKE_PROGRAM}"
                               -D "OUTPUT=${CMAKE_BINARY_DIR}/${arg_OUTPUT}"
                               -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/clang-tools/run-clang-tidy.cmake"
                       BYPRODUCTS "${CMAKE_BINARY_DIR}/.clang-tools/${target}/${config_subdir}/clang-tidy.ninja"
                       DEPENDS ${arg_DEPENDS}
                               "${depends}"
                               "${clang-tidy_EXE}"
                               "${CMAKE_BINARY_DIR}/.clang-tools/${target}/${config_subdir}compile_commands.json"
                               "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/clang-tools/run-clang-tidy.cmake"
                               "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/clang-tools/cat.cmake"
                               "${CMAKE_BINARY_DIR}/.clang-tools/${target}/${config_subdir}clang-tidy-checks.arg"
                       DEPFILE "${CMAKE_BINARY_DIR}/.clang-tools/${target}/${config_subdir}clang-tidy.d"
                       WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
                       COMMENT "clang-tidy (${target}): Analyzing"
                       JOB_POOL use_all_cpus
                       VERBATIM)
endfunction()

function(z_clang_tidy_checks target results)
    add_custom_command(OUTPUT "${target_compile_commands_path}clang-tidy-checks.arg"
                       COMMAND "${CMAKE_COMMAND}"
                               -D "TARGET=${target}"
                               -D "FILE=${target_compile_commands_path}clang-tidy-checks.arg"
                               -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/clang-tools/clang-tidy-checks.cmake"
                       BYPRODUCTS "${target_compile_commands_path}clang-tidy-checks.run-always"
                       # No dependencies required - runs on each build
                       COMMENT "Checking clang-tidy overrides"
                       VERBATIM)
endfunction()

function(clang_tidy #[[ <target> ... ]])
    # Brute force for the time being, could be replaced by .d files per source
    file(GLOB_RECURSE depends LIST_DIRECTORIES NO .clang-tidy)
    clang_tools_run(clang-tidy
                    TARGETS ${ARGV}
                    UNITY z_clang_tidy_unity
                    MAP_CUSTOM  z_clang_tidy_checks
                    MAP_COMMAND "@CMAKE_COMMAND@"
                               -D "clang-tidy_EXE=@clang-tidy_EXE@"
                               -D "COMPILE_COMMANDS_PATH=@target_compile_commands_path@"
                               -D "FILES=@files@"
                               -D "OUTPUT=@output@"
                               -P "@CMAKE_CURRENT_FUNCTION_LIST_DIR@/clang-tools/run-clang-tidy.cmake"
                    MAP_DEPENDS "@CMAKE_CURRENT_FUNCTION_LIST_DIR@/clang-tools/run-clang-tidy.cmake"
                                "@clang-tidy_EXE@"
                                "@target_compile_commands_path@compile_commands.json"
                                "@target_compile_commands_path@clang-tidy-checks.arg"
                                ${depends}
                    MAP_DEPFILE
                    MAP_EXTENSION tidy)
endfunction()
