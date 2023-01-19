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
# Common module for clang-tidy and include-what-you-use. Additionally adds function to check precompiled headers.
# Adds function: check_pch([ ALL | <target> ...]).
# Set variable IWYU_EXE if include-what-you-use is not found automatically.
#

include(FindPackageHandleStandardArgs)

set(ClangTools_VERSION "1.1.0")
find_package_handle_standard_args(ClangTools
                                  REQUIRED_VARS ClangTools_VERSION
                                  VERSION_VAR ClangTools_VERSION
                                  HANDLE_VERSION_RANGE)

if(NOT ClangTools_FOUND)
    return()
endif()
include_guard(GLOBAL)

# Read version of clang executable
function(z_clang_get_version)
    execute_process(COMMAND "${clang_EXE}" --version OUTPUT_VARIABLE out)
    if(out MATCHES "clang version ([0-9.]+)")
        set(clang_VERSION "${CMAKE_MATCH_1}" PARENT_SCOPE)
    endif()
endfunction()

# Get path of clang executable
if(NOT clang_EXE)
    find_program(clang_EXE NAMES clang clang-cl PATHS "${clang_ROOT}" ENV clang_ROOT)
    mark_as_advanced(clang_EXE)
    if(clang_EXE)
        z_clang_get_version()
        if(clang_VERSION VERSION_LESS "13.0.0")
            message(STATUS "Could NOT find clang: Found unsuitable version \"${clang_VERSION}\", but required is at least \"13.0.0\"")
            unset(clang_EXE CACHE)
        else()
            message(STATUS "Found clang: ${clang_EXE} (found version \"${clang_VERSION}\")")
        endif()
    else()
        message(STATUS "Could NOT find clang")
    endif()
endif()

#
# Helpers
#

include("${CMAKE_CURRENT_LIST_DIR}/Regex.cmake")

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
        get_target_property(vcpkg "${target}" vcpkg_LOCAL)
        cmake_path(IS_PREFIX PROJECT_BINARY_DIR "${binary_dir}" NORMALIZE is_in_project)
        if(is_in_project AND NOT aliased AND NOT imported AND NOT vcpkg AND type MATCHES "^((INTERFACE|MODULE|OBJECT|SHARED|STATIC)_LIBRARY|EXECUTABLE)$")
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
 function(clang_tools_run #[[ <tool> [ [ NAME <name> ] TARGETS <target> ... [ FILTER <function> ] [UNITY <function>] [ MAP_INCLUDES ] [ MAP_SOURCES ] [ MAP_CUSTOM <function> ] [ MAP_COMMAND <command> [ <arg> ... ] [ MAP_DEPENDS <depdency> ... [ MAP_DEPFILE ] [ MAP_EXTENSION <extension> ] [ MAP_JOB_POOL <pool> ] ] [ REDUCE_COMMAND <command> [ <arg> ... ] [ REDUCE_DEPENDS <dependency> ... ] ] ]])
    # Force replacement of variables inside this function
    string(CONFIGURE [=[cmake_language(DEFER DIRECTORY "${PROJECT_BINARY_DIR}" CALL z_clang_tools_deferred @ARGV@)]=] code @ONLY ESCAPE_QUOTES)
    cmake_language(EVAL CODE ${code})
endfunction()

function(z_clang_tools_add_source_dependency source)
    add_custom_command(OUTPUT "${target_compile_commands_path}compile_commands.json"
                       DEPENDS "${source}"
                       APPEND)
endfunction()

#
# Helper function used by clang_tools_run. Actually run the commands for all targets.
#
function(z_clang_tools_deferred tool #[[ [ NAME <name> ] TARGETS <target> ... [ FILTER <function> ] [UNITY <function>] [ MAP_INCLUDES ] [ MAP_SOURCES ] [ MAP_CUSTOM <function> ] [ MAP_COMMAND <command> [ <arg> ... ] [ MAP_DEPENDS <depdency> ... [ MAP_DEPFILE ] [ MAP_EXTENSION <extension> ] [ MAP_JOB_POOL <pool> ] ] [ REDUCE_COMMAND <command> [ <arg> ... ] [ REDUCE_DEPENDS <dependency> ... ] ] ]])
    cmake_parse_arguments(PARSE_ARGV 1 arg "MAP_INCLUDES;MAP_SOURCES;MAP_DEPFILE" "NAME;FILTER;UNITY;MAP_CUSTOM;MAP_EXTENSION;MAP_JOB_POOL" "TARGETS;MAP_COMMAND;MAP_DEPENDS;REDUCE_COMMAND;REDUCE_DEPENDS")
    if(NOT arg_NAME)
        set(arg_NAME "${tool}")
    endif()
    if(NOT arg_MAP_EXTENSION)
        set(arg_MAP_EXTENSION "${tool}")
    endif()
    if(NOT arg_TARGETS)
        message(FATAL_ERROR "clang_tools_run: TARGETS is missing or empty")
    endif()
    if(NOT arg_MAP_COMMAND AND NOT arg_MAP_INCLUDES)
        message(FATAL_ERROR "clang_tools_run: MAP_COMMAND is missing or empty")
    endif()

    if(arg_TARGETS STREQUAL "ALL")
        unset(arg_TARGETS)
        cmake_utils_for_each_target(z_clang_tools_visit_target ARGS "${tool}" arg_TARGETS DIRECTORY "${CMAKE_SOURCE_DIR}" OUT arg_TARGETS)
    endif()

    string(ASCII 27 esc)

    # Use sub-directory in case of multi-config
    get_property(is_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
    if(is_multi_config)
        set(config_subdir "$<CONFIG>/")
    else()
        unset(config_subdir)
    endif()

    # Extensions of source files
    set(extensions ${CMAKE_CXX_SOURCE_FILE_EXTENSIONS})
    list(APPEND extensions ${CMAKE_C_SOURCE_FILE_EXTENSIONS})

    # Extensions (without .) as a pattern for matching in regular expressions
    regex_escape_pattern(extensions OUT extensions_pattern)
    list(JOIN extensions_pattern "|" extensions_pattern)

    # Extensions (with .) as a filter for generator expression IN_LIST
    list(TRANSFORM extensions PREPEND ".")
    list(JOIN extensions "$<SEMICOLON>" extensions_genex)

    foreach(target IN LISTS arg_TARGETS)
        if(arg_FILTER)
            cmake_language(CALL "${arg_FILTER}" "${target}" process)
            if(NOT process)
                continue()
            endif()
        endif()

        get_target_property(target_source_dir "${target}" SOURCE_DIR)
        get_target_property(target_binary_dir "${target}" BINARY_DIR)
        get_target_property(target_sources "${target}" SOURCES)

        # Filter for unity builds
        get_target_property(target_unity "${target}" UNITY_BUILD)
        if(target_unity AND NOT arg_UNITY)
            message(STATUS "Not supported in unity build: ${tool}-${target}")
            continue()
        endif()

        # Main target for tool
        if(NOT TARGET "${tool}")
            message(STATUS "Creating target: ${tool}")
            add_custom_target("${tool}" COMMENT "${arg_NAME}")
        endif()

        if(target_unity)
            message(STATUS "Creating target: ${tool}-${target} (unity build)")
        else()
            message(STATUS "Creating target: ${tool}-${target}")
        endif()

        # All tools use a shared compile_commands.json per target
        set(target_compile_commands_path "${CMAKE_BINARY_DIR}/.clang-tools/${target}/${config_subdir}")
        get_target_property(target_compile_commands "${target}" CLANG_TOOLS_COMPILE_COMMANDS)
        if(NOT target_compile_commands)
            # Request generation of compile_commands.json
            set_target_properties("${target}" PROPERTIES EXPORT_COMPILE_COMMANDS YES
                                                         CLANG_TOOLS_COMPILE_COMMANDS YES)

            # Create compile_commands.json for clang from MSVC version.
            add_custom_command(OUTPUT "${target_compile_commands_path}compile_commands.json"
                               COMMAND "${CMAKE_COMMAND}"
                                       -D "TARGET=${target}"
                                       -D "CONFIG_SUBDIR=${config_subdir}"
                                       -D "clang_EXE=${clang_EXE}"
                                       -D "MSVC_VERSION=${MSVC_VERSION}"
                                       -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/clang-tools/compile_commands.cmake"
                               DEPENDS "${CMAKE_BINARY_DIR}/compile_commands.json"
                                       "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/clang-tools/compile_commands.cmake"
                               WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
                               COMMENT "${target}: Patching compile_commands.json"
                               VERBATIM)
        endif()

        # Main tool target prints log file to stderr
        set(main_output "${config_subdir}${tool}-${target}.log")
        add_custom_target("${tool}-${target}"
                          COMMAND "${CMAKE_COMMAND}" -E echo "${esc}[92m${arg_NAME}: ${target}${esc}[m"
                          COMMAND "${CMAKE_COMMAND}"
                                  -D "TOOL=${tool}"
                                  -D "SOURCE_DIR=${PROJECT_SOURCE_DIR}"
                                  -D "FILES=${main_output}"
                                  -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/clang-tools/cat-result.cmake"
                          DEPENDS "${CMAKE_BINARY_DIR}/${main_output}"
                          WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
                          COMMENT "${arg_NAME} (${target})"
                          VERBATIM)
        add_dependencies("${tool}" "${tool}-${target}")

        unset(sources)
        unset(results)
        unset(has_genex)

        # Hook to add additional processing logic
        if(arg_MAP_CUSTOM)
            cmake_language(CALL "${arg_MAP_CUSTOM}" "${target}" results)
        endif()

        if(target_unity)
            foreach(source IN LISTS target_sources)
                string(GENEX_STRIP "${source}" source_no_genex)
                if("${source}" STREQUAL "${source_no_genex}" AND NOT IS_ABSOLUTE "${source}")
                    set(source "${target_source_dir}/${source}")
                endif()
                list(APPEND sources "${source}")
            endforeach()

            cmake_language(CALL "${arg_UNITY}" "${target}" OUTPUT "${main_output}" DEPENDS ${sources} ${arg_MAP_DEPENDS} ${arg_REDUCE_DEPENDS})
            continue()
        endif()

        if(arg_MAP_INCLUDES)
            get_target_property(target_map_includes "${target}" CLANG_TOOLS_MAP_INCLUDES)
            set_target_properties("${target}" PROPERTIES CLANG_TOOLS_MAP_INCLUDES YES)
        endif()

        foreach(source IN LISTS target_sources)
            set(target_source "${source}")
            string(GENEX_STRIP "${source}" source_no_genex)
            if("${source}" STREQUAL "${source_no_genex}")
                if(IS_ABSOLUTE "${source}")
                    cmake_path(IS_PREFIX PROJECT_SOURCE_DIR "${source}" NORMALIZE is_in_source)
                    cmake_path(IS_PREFIX PROJECT_BINARY_DIR "${source}" NORMALIZE is_in_binary)
                    if(NOT is_in_source OR is_in_binary)
                        z_clang_tools_add_source_dependency("${source}")
                        continue()
                    endif()
                else()
                    set(source "${target_source_dir}/${source}")
                endif()

                get_source_file_property(generated "${source}" TARGET "${target}" GENERATED)
                if(generated)
                    z_clang_tools_add_source_dependency("${source}")
                    continue()
                endif()

                get_source_file_property(header "${source}" TARGET "${target}" HEADER_FILE_ONLY)
                if (header)
                    z_clang_tools_add_source_dependency("${source}")
                    continue()
                endif()

                if (NOT source MATCHES ".*\\.(${extensions_pattern})$")
                    z_clang_tools_add_source_dependency("${source}")
                    continue()
                endif()

                unset(pre)
                unset(post)

                cmake_path(RELATIVE_PATH source BASE_DIRECTORY "${PROJECT_SOURCE_DIR}" OUTPUT_VARIABLE relative)
            else()
                get_source_file_property(generated "${source}" TARGET "${target}" GENERATED)
                if(generated)
                    z_clang_tools_add_source_dependency("${source}")
                    continue()
                endif()

                set(has_genex TRUE)

                set(if_extension "$<IN_LIST:$<PATH:GET_EXTENSION,LAST_ONLY,${source}>,${extensions}>")
                set(if_in_source "$<PATH:IS_PREFIX,NORMALIZE,${target_source_dir},${source}>")
                set(if_source "$<AND:${if_extension},${if_in_source}>")
                set(pre "$<${if_source}:")
                set(post ">")

                set(relative "$<PATH:RELATIVE_PATH,${source},${PROJECT_SOURCE_DIR}>")
            endif()

            list(APPEND sources "${pre}${source}${post}")

            if(arg_MAP_INCLUDES)
                set(output "${CMAKE_BINARY_DIR}/.clang-tools/${target}/${config_subdir}${relative}.inc")
                if(NOT target_map_includes)
                    set(command "@CMAKE_COMMAND@"
                                -D "TARGET=@target@"
                                -D "PROJECT_SOURCE_DIR=@PROJECT_SOURCE_DIR@"
                                -D "PROJECT_BINARY_DIR=@PROJECT_BINARY_DIR@"
                                -D "BINARY_DIR=@target_binary_dir@"
                                -D "CONFIG_SUBDIR=@config_subdir@"
                                -D "FILES=@source@"
                                -D "OUTPUT=@output@"
                                -P "@CMAKE_CURRENT_FUNCTION_LIST_DIR@/clang-tools/scan-includes.cmake")

                    z_clang_tools_configure("${command}" command)

                    add_custom_command(OUTPUT "${pre}${output}${post}"
                                       COMMAND "${pre}${command}${post}"
                                       DEPENDS "${pre}${source}${post}"
                                               "${target_compile_commands_path}compile_commands.json"
                                               "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/clang-tools/scan-includes.cmake"
                                       DEPFILE "${pre}${output}.d${post}"
                                       WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
                                       COMMENT "${target}: Includes of ${target_source}"
                                       VERBATIM COMMAND_EXPAND_LISTS)
                endif()
                set(includes "${output}")
            endif()

            if(arg_MAP_COMMAND)
                set(files "${source}")
                set(output "${CMAKE_BINARY_DIR}/.clang-tools/${target}/${config_subdir}${relative}.${arg_MAP_EXTENSION}")

                z_clang_tools_configure("${arg_MAP_COMMAND}" command)
                z_clang_tools_configure("${arg_MAP_DEPENDS}" depends)
                if(arg_MAP_INCLUDES)
                    list(APPEND depends "${pre}${includes}${post}")
                endif()
                if(arg_MAP_SOURCES)
                    list(APPEND depends "${pre}${CMAKE_BINARY_DIR}/.clang-tools/${target}/${config_subdir}.sources${post}")
                endif()
                if(arg_MAP_DEPFILE)
                    set(depfile DEPFILE "@pre@@output@.d@post@")
                    z_clang_tools_configure("${depfile}" depfile)
                else()
                    unset(depfile)
                endif()
                if(arg_MAP_JOB_POOL)
                    z_clang_tools_configure("${arg_MAP_JOB_POOL}" job_pool)
                    set(job_pool JOB_POOL "${job_pool}")
                else()
                    unset(job_pool)
                endif()

                add_custom_command(OUTPUT "${pre}${output}${post}"
                                   COMMAND "${pre}${command}${post}"
                                   DEPENDS "${pre}${source}${post}"
                                           "${target_compile_commands_path}compile_commands.json"
                                           "${depends}"
                                   ${depfile}
                                   WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
                                   COMMENT "${arg_NAME} (${target}): ${target_source}"
                                   ${job_pool}
                                   VERBATIM COMMAND_EXPAND_LISTS)
            endif()

            # Use include file for reduce step if no map command is present
            list(APPEND results "${pre}${output}${post}")
        endforeach()

        if(arg_MAP_SOURCES)
            get_target_property(target_map_sources "${target}" CLANG_TOOLS_MAP_SOURCES)
            if(NOT target_map_sources)
                set_target_properties("${target}" PROPERTIES CLANG_TOOLS_MAP_SOURCES YES)
                file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/.clang-tools/${target}/${config_subdir}.sources" CONTENT "$<JOIN:$<FILTER:${sources},EXCLUDE,^$>,\r\n>" TARGET "${target}")
            endif()
        endif()

        # Aggregate results into final output
        if(results)
            #list(SORT results CASE INSENSITIVE)
            if(has_genex)
                list(JOIN results "$<SEMICOLON>" results)
                set(files "$<JOIN:$<FILTER:${results},EXCLUDE,^$>,;>")
            else()
                list(JOIN results ";" files)
            endif()
            set(output "${main_output}")

            # use relative path for command
            if(arg_REDUCE_COMMAND)
                set(command "${arg_REDUCE_COMMAND}")
                set(depends "${arg_REDUCE_DEPENDS}")
            else()
                # cmake -E cat Does not work: Stops on empty file as of CMake 3.20.0.
                set(command "@CMAKE_COMMAND@"
                            -D "TOOL=@tool@"
                            -D "FILES=@files@"
                            -D "FILES_DIR=@CMAKE_BINARY_DIR@/.clang-tools/@target@/@config_subdir@"
                            -D "OUTPUT=@output@"
                            -P "@CMAKE_CURRENT_FUNCTION_LIST_DIR@/clang-tools/cat.cmake")
                set(depends "@CMAKE_CURRENT_FUNCTION_LIST_DIR@/clang-tools/cat.cmake")
            endif()

            z_clang_tools_configure("${command}" command)
            z_clang_tools_configure("${depends}" depends)

            add_custom_command(OUTPUT "${CMAKE_BINARY_DIR}/${output}"
                               COMMAND "${command}"
                               DEPENDS "${files}"
                                       "${depends}"
                               WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
                               COMMENT "${arg_NAME} (${target}): Analyzing output"
                               VERBATIM COMMAND_EXPAND_LISTS)
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
    # Use sub-directory in case of multi-config
    get_property(is_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
    if(is_multi_config)
        set(config_subdir "$<CONFIG>/")
    else()
        unset(config_subdir)
    endif()


    get_target_property(target_binary_dir "${target}" BINARY_DIR)

    # Output for all precompiled headers in a single file
    set(output ".clang-tools/${target}/${config_subdir}cmake_pch.inc")

    # scan HEADER for PCH
    add_custom_command(OUTPUT "${CMAKE_BINARY_DIR}/${output}"
                       COMMAND "${CMAKE_COMMAND}"
                               -D "TARGET=${target}"
                               -D "PROJECT_SOURCE_DIR=${PROJECT_SOURCE_DIR}"
                               -D "PROJECT_BINARY_DIR=${PROJECT_BINARY_DIR}"
                               -D "BINARY_DIR=${target_binary_dir}"
                               -D "CONFIG_SUBDIR=${config_subdir}"
                               -D "PCH=ON"
                               -D "OUTPUT=${output}"
                               -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/clang-tools/scan-includes.cmake"
                       DEPENDS "${CMAKE_BINARY_DIR}/.clang-tools/${target}/${config_subdir}compile_commands.json"
                               "$<TARGET_GENEX_EVAL:${target},$<TARGET_PROPERTY:${target},PRECOMPILE_HEADERS>>"
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
if(clang_EXE)
    function(check_pch #[[ <target> ... ]])
        clang_tools_run(pch
                        TARGETS ${ARGV}
                        FILTER z_clang_tools_pch_used
                        MAP_INCLUDES
                        MAP_CUSTOM z_clang_tools_pch_scan_command
                        REDUCE_COMMAND "@CMAKE_COMMAND@"
                                       -D "TARGET=@target@"
                                       -D "CONFIG_SUBDIR=@config_subdir@"
                                       -D "FILES=@files@"
                                       -D "PCH_FILES=$<JOIN:$<TARGET_GENEX_EVAL:@target@,$<TARGET_PROPERTY:@target@,PRECOMPILE_HEADERS>>,\\\\;>"
                                       -D "OUTPUT=@output@"
                                       -P "@CMAKE_CURRENT_FUNCTION_LIST_DIR@/clang-tools/check-pch.cmake"
                        REDUCE_DEPENDS "@CMAKE_CURRENT_FUNCTION_LIST_DIR@/clang-tools/check-pch.cmake")
    endfunction()
endif()
