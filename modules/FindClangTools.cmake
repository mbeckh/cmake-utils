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
# Common module for clang-tidy and include-what-you-use. Additionally adds function to check precompiled headers.
# Adds function: check_pch([ ALL | <target> ...]).
# Set variable IWYU_EXE if include-what-you-use is not found automatically.
#

include(FindPackageHandleStandardArgs)

set(ClangTools_VERSION "0.0.1")
find_package_handle_standard_args(ClangTools
                                  REQUIRED_VARS ClangTools_VERSION
                                  VERSION_VAR ClangTools_VERSION
                                  HANDLE_VERSION_RANGE)

if(NOT ClangTools_FOUND)
    return()
endif()
include_guard(GLOBAL)


#
# Helpers
#

include("${CMAKE_CURRENT_LIST_DIR}/Regex.cmake")

#
# Store a regex pattern for all known C/C++ source extensions in var.
#
function(z_clang_tools_source_extensions var)
    set(extensions ${CMAKE_CXX_SOURCE_FILE_EXTENSIONS})
    list(APPEND extensions ${CMAKE_C_SOURCE_FILE_EXTENSIONS})
    regex_escape_pattern(extensions)
    list(JOIN extensions "|" extensions)

    set("${var}" "${extensions}" PARENT_SCOPE)
endfunction()

#
# Proper configure for values containing semicolons and store result in var.
#
function(z_clang_tools_configure value var)
    string(REGEX MATCHALL "@[^@]+@" matches "${value}")
    list(TRANSFORM matches REPLACE "^@(.+)@$" "\\1")
    foreach(variable IN LISTS matches)
        string(REPLACE ";" "\\;" "${variable}" "${${variable}}")
    endforeach()
    string(CONFIGURE "${value}" result @ONLY ESCAPE_QUOTES)
    set("${var}" "${result}" PARENT_SCOPE)
endfunction()

#
# Append target to list var if not already visited for tool.
#
function(z_clang_tools_visit_target target tool var)
    if(NOT TARGET "${tool}-${target}")
        get_target_property(aliased "${target}" ALIASED_TARGET)
        get_target_property(binary_dir "${target}" BINARY_DIR)
        get_target_property(imported "${target}" IMPORTED)
        get_target_property(type "${target}" TYPE)
        cmake_path(IS_PREFIX PROJECT_BINARY_DIR "${binary_dir}" NORMALIZE is_in_project)
        if(is_in_project AND NOT aliased AND NOT imported AND type MATCHES "^((INTERFACE|MODULE|OBJECT|SHARED|STATIC)_LIBRARY|EXECUTABLE)$")
            set(result "${${var}}")
            list(APPEND result "${target}")
            set("${var}" "${result}" PARENT_SCOPE)
        endif()
    endif()
endfunction()

#
# Main entry function to run commands for all source files.
# Schedules call until current directory is processed so that targets are fully populated.
#
 function(clang_tools_run #[[ <tool> [ [ NAME <name> ] TARGETS <target> ... [ FILTER <function> ] MAP_COMMAND <command> [ <arg> ... ] [ MAP_DEPENDS <depdency> ... ] [ MAP_EXTENSION <extension> ] [ MAP_CUSTOM <function> ] [ WITH_AUX_INCLUDE ] [ REDUCE_COMMAND <command> [ <arg> ... ] [ REDUCE_DEPENDS <dependency> ... ] ] ]])
    # Force replacement of variables inside this function
    string(CONFIGURE [=[cmake_language(DEFER DIRECTORY "${PROJECT_BINARY_DIR}" CALL z_clang_tools_deferred @ARGV@)]=] code @ONLY ESCAPE_QUOTES)
    cmake_language(EVAL CODE ${code})
endfunction()

#
# Helper function used by clang_tools_run. Actually run the commands for all targets.
#
function(z_clang_tools_deferred tool #[[ [ NAME <name> ] TARGETS <target> ... [ FILTER <function> ] MAP_COMMAND <command> [ <arg> ... ] [ MAP_DEPENDS <depdency> ... ] [ MAP_EXTENSION <extension> ] [ MAP_CUSTOM <function> ] [ WITH_AUX_INCLUDE ] [ REDUCE_COMMAND <command> [ <arg> ... ] [ REDUCE_DEPENDS <dependency> ... ] ] ]])
    cmake_parse_arguments(PARSE_ARGV 1 arg "WITH_AUX_INCLUDE" "NAME;FILTER;MAP_EXTENSION;MAP_CUSTOM" "TARGETS;MAP_COMMAND;MAP_DEPENDS;REDUCE_COMMAND;REDUCE_DEPENDS")
    if(NOT arg_NAME)
        set(arg_NAME "${tool}")
    endif()
    if(NOT arg_MAP_EXTENSION)
        set(arg_MAP_EXTENSION "${tool}")
    endif()
    if(NOT arg_TARGETS)
        message(FATAL_ERROR "TARGETS are missing for clang_tools_run")
    endif()
    if(NOT arg_MAP_COMMAND)
        message(FATAL_ERROR "MAP_COMMAND is missing for clang_tools_run")
    endif()

    if(arg_TARGETS STREQUAL "ALL")
        unset(arg_TARGETS)
        cmake_utils_for_each_target(z_clang_tools_visit_target ARGS "${tool}" arg_TARGETS DIRECTORY "${CMAKE_SOURCE_DIR}" OUT arg_TARGETS)
    endif()

    # Create compile_commands.json for clang from MSVC version.
    if(NOT TARGET "clang-tools-compile_commands")
        message(STATUS "Creating target: clang-tools-compile_commands")
        add_custom_target(clang-tools-compile_commands
                          DEPENDS "${CMAKE_BINARY_DIR}/.clang-tools/compile_commands.json"
                          WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
                          COMMENT "Patching compile_commands.json"
                          VERBATIM)

        add_custom_command(OUTPUT "${CMAKE_BINARY_DIR}/.clang-tools/compile_commands.json"
                           COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/clang-tools/compile_commands.cmake"
                           DEPENDS "${CMAKE_BINARY_DIR}/compile_commands.json"
                                   "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/clang-tools/compile_commands.cmake"
                           WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
                           COMMENT "Patching compile_commands.json"
                           VERBATIM)
    endif()

    # Main target
    if(NOT TARGET "${tool}")
        message(STATUS "Creating target: ${tool}")
        add_custom_target("${tool}" COMMENT "${arg_NAME}")
    endif()

    z_clang_tools_source_extensions(extensions)

    string(ASCII 27 esc)
    foreach(target IN LISTS arg_TARGETS)
        if(arg_FILTER)
            cmake_language(CALL "${arg_FILTER}" "${target}" process)
            if(NOT process)
                continue()
            endif()
        endif()
        # Request generation of compile_commands.json
        set_target_properties("${target}" PROPERTIES EXPORT_COMPILE_COMMANDS YES)

        get_target_property(source_dir "${target}" SOURCE_DIR)
        get_target_property(binary_dir "${target}" BINARY_DIR)
        get_target_property(target_sources "${target}" SOURCES)

        # Main tool target
        message(STATUS "Creating target: ${tool}-${target}")
        set(main_output "${tool}-${target}.log")
        add_custom_target("${tool}-${target}"
                          COMMAND "${CMAKE_COMMAND}" -E echo "${esc}[92m${arg_NAME}: ${target}${esc}[m"
                          COMMAND "${CMAKE_COMMAND}"
                                  -D "TOOL=${tool}"
                                  -D "SOURCE_DIR=${source_dir}"
                                  -D "FILES=${main_output}"
                                  -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/clang-tools/cat-result.cmake"
                          DEPENDS "${CMAKE_BINARY_DIR}/${main_output}"
                          WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
                          COMMENT "${arg_NAME} (${target})"
                          VERBATIM)
        add_dependencies("${tool}" "${tool}-${target}")

        # Get lists of sources, object files and includes
        unset(sources)
        unset(objects)
        unset(includes)
        unset(aux_includes_maps)
        foreach(source IN LISTS target_sources)
            get_source_file_property(location "${source_dir}/${source}" LOCATION)
            get_source_file_property(header "${location}" HEADER_FILE_ONLY)
            if (source MATCHES ".*\\.(${extensions})" AND NOT header)
                list(APPEND sources "${location}")

                get_source_file_property(language "${source_dir}/${source}" LANGUAGE)
                list(APPEND objects "${binary_dir}/CMakeFiles/${target}.dir/${source}${CMAKE_${language}_OUTPUT_EXTENSION}")

                if(arg_WITH_AUX_INCLUDE)
                    list(APPEND aux_includes_maps "${CMAKE_BINARY_DIR}/.clang-tools/${target}/${source}.auxi")
                endif()
            else()
                list(APPEND includes "${location}")
            endif()
        endforeach()

        # Get list of auxiliary includes if required
        if(arg_WITH_AUX_INCLUDE)
            if(NOT TARGET "clang-tools-analyze-aux-includes-${target}")
                if(NOT CMAKE_GENERATOR STREQUAL Ninja)
	                message(FATAL_ERROR "Supported for Ninja only: ${CMAKE_GENERATOR}")
                endif()
                # Filter out "main" includes
                set(aux_includes "${includes}")
                foreach(source IN LISTS sources)
                    cmake_path(GET source STEM LAST_ONLY base_name)
                    string(REGEX REPLACE "(_(unit|reg)?test)|(-inl)$" "" canonical_base_name "${base_name}")
                    regex_escape_pattern(base_name)
                    regex_escape_pattern(canonical_base_name)
                    list(FILTER aux_includes EXCLUDE REGEX "(^|.+/)(${base_name}|${canonical_base_name})\\.(h|H|hpp|hxx|hh|inl)$")
                endforeach()

                add_custom_command(OUTPUT "${CMAKE_BINARY_DIR}/.clang-tools/${target}/.aux-includes"
                                   COMMAND "${CMAKE_COMMAND}"
                                           -D "CMAKE_MAKE_PROGRAM=${CMAKE_MAKE_PROGRAM}"
                                           -D "TARGET=${target}"
                                           -D "SOURCE_DIR=${source_dir}"
                                           -D "SOURCES=${sources}"
                                           -D "INCLUDES=${includes}"
                                           -D "AUX_INCLUDES=${aux_includes}"
                                           -D "OUTPUTS=${aux_includes_maps}"
                                           -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/clang-tools/aux-includes.cmake"
                                   DEPENDS ${objects}
                                           "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/clang-tools/aux-includes.cmake"
                                   BYPRODUCTS ${aux_includes_maps}
                                   WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
                                   COMMENT "Analyzing auxiliary includes (${target})"
                                   VERBATIM)
            endif()
        endif()

        # Run command for all source files
        unset(results)
        foreach(source object aux_includes_map IN ZIP_LISTS sources objects aux_includes_maps)
            set(files "${source}")
            set(aux_includes_files "${aux_includes_map}")
            cmake_path(RELATIVE_PATH source BASE_DIRECTORY "${source_dir}" OUTPUT_VARIABLE relative)
            set(output ".clang-tools/${target}/${relative}.${arg_MAP_EXTENSION}")

            z_clang_tools_configure("${arg_MAP_COMMAND}" command)
            z_clang_tools_configure("${arg_MAP_DEPENDS}" depends)

            if(arg_WITH_AUX_INCLUDE)
                list(APPEND depends "${CMAKE_BINARY_DIR}/.clang-tools/${target}/.aux-includes")
                list(APPEND depends "${CMAKE_BINARY_DIR}/.clang-tools/${target}/${relative}.auxi")
            endif()

            add_custom_command(OUTPUT "${CMAKE_BINARY_DIR}/${output}"
                               COMMAND ${command}
                               DEPENDS "${object}"
                                       clang-tools-compile_commands
                                       ${depends}
                               WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
                               COMMENT "${arg_NAME} (${target}): ${relative}"
                               VERBATIM)
            list(APPEND results "${CMAKE_BINARY_DIR}/${output}")
        endforeach()

        # Hook to add additional processing logic
        if(arg_MAP_CUSTOM)
            cmake_language(CALL "${arg_MAP_CUSTOM}" "${target}" results)
        endif()

        # Aggregate results into final output
        if(results)
            list(SORT results CASE INSENSITIVE)

            set(files "${results}")
            set(output "${main_output}")

            # use relative path for command
            if(arg_REDUCE_COMMAND)
                set(command "${arg_REDUCE_COMMAND}")
                set(depends "${arg_REDUCE_DEPENDS}")
            else()
                # cmake -E cat Does not work: Stops on empty file as of CMake 3.20.0.
                set(command "@CMAKE_COMMAND@"
                            -D "FILES=@files@"
                            -D "OUTPUT=@output@"
                            -P "@CMAKE_CURRENT_FUNCTION_LIST_DIR@/clang-tools/cat.cmake")
                set(depends "@CMAKE_CURRENT_FUNCTION_LIST_DIR@/clang-tools/cat.cmake")
            endif()
            z_clang_tools_configure("${command}" command)
            z_clang_tools_configure("${depends}" depends)

            add_custom_command(OUTPUT "${CMAKE_BINARY_DIR}/${output}"
                                COMMAND ${command}
                                DEPENDS ${files}
                                        ${depends}
                                WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
                                COMMENT "${arg_NAME} (${target}): Analyzing output"
                                VERBATIM)
        else()
            add_custom_command(OUTPUT "${CMAKE_BINARY_DIR}/${main_output}"
                               COMMAND "${CMAKE_COMMAND}" -E touch "${main_output}"
                               WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
                               COMMENT "${arg_NAME} (${target}): Nothing to do"
                               VERBATIM)
        endif()
    endforeach()
endfunction()

#
# Check if target is using pre-compiled headers and store result in var.
#
function(z_clang_tools_pch_used target var)
    get_target_property(precompile_headers "${target}" PRECOMPILE_HEADERS)
    if(precompile_headers)
        set("${var}" YES PARENT_SCOPE)
    else()
        set("${var}" NO PARENT_SCOPE)
    endif()
endfunction()

#
# Adds custom command to scan includes of pre-compiled headers and append output to list var.
#
function(z_clang_tools_pch_scan_command target var)
    get_target_property(source_dir "${target}" SOURCE_DIR)
    get_target_property(binary_dir "${target}" BINARY_DIR)

    set(output ".clang-tools/${target}/cmake_pch.si")
    # scan HEADER for PCH
    add_custom_command(OUTPUT "${CMAKE_BINARY_DIR}/${output}"
                       COMMAND "${CMAKE_COMMAND}"
                               -D "TARGET=${target}"
                               -D "SOURCE_DIR=${source_dir}"
                               -D "BINARY_DIR=${binary_dir}"
                               -D "PCH=$<JOIN:$<TARGET_PROPERTY:${target},PRECOMPILE_HEADERS>,$<SEMICOLON>>"
                               -D "OUTPUT=${output}"
                               -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/clang-tools/scan-includes.cmake"
                       DEPENDS clang-tools-compile_commands
                               "$<TARGET_PROPERTY:${target},PRECOMPILE_HEADERS>"
                               "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/clang-tools/scan-includes.cmake"
                       WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
                       COMMENT "${arg_NAME} (${target}): Precompiled Header"
                       VERBATIM)
    set(results "${${var}}")
    list(APPEND results "${CMAKE_BINARY_DIR}/${output}")
    set("${var}" "${results}" PARENT_SCOPE)
endfunction()

#
# Check pre-compiled header for missing or unused entries.
# The function assumes that the pre-compiled header is a user-created file.
# It does not make any sens to call that function when adding system headers directly in target_precompile_headers
#
function(check_pch #[[ <target> ... ]])
    clang_tools_run(pch
                    TARGETS ${ARGV}
                    FILTER z_clang_tools_pch_used
                    MAP_COMMAND "@CMAKE_COMMAND@"
                                -D "TARGET=@target@"
                                -D "SOURCE_DIR=@source_dir@"
                                -D "BINARY_DIR=@binary_dir@"
                                -D "FILES=@files@"
                                -D "OUTPUT=@output@"
                                -P "@CMAKE_CURRENT_FUNCTION_LIST_DIR@/clang-tools/scan-includes.cmake"
                    MAP_DEPENDS "@CMAKE_CURRENT_FUNCTION_LIST_DIR@/clang-tools/scan-includes.cmake"
                    MAP_EXTENSION si
                    MAP_CUSTOM z_clang_tools_pch_scan_command
                    REDUCE_COMMAND "@CMAKE_COMMAND@"
                                   -D "TARGET=@target@"
                                   -D "FILES=@files@"
                                   -D "PCH_FILES=$<TARGET_PROPERTY:@target@,PRECOMPILE_HEADERS>"
                                   -D "OUTPUT=@output@"
                                   -P "@CMAKE_CURRENT_FUNCTION_LIST_DIR@/clang-tools/check-pch.cmake"
                    REDUCE_DEPENDS "@CMAKE_CURRENT_FUNCTION_LIST_DIR@/clang-tools/check-pch.cmake")
endfunction()
