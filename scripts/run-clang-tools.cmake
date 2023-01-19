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
# Run build command for one or several files.
# Can e.g. be used inside Visual Studio as an external tool to run clang-tidy, include-what-you-use or PCH check for a
# file from within the IDE with the following settings.
# - Command: Path of CMake.exe
# - Arguments: -D TOOL=[compile | clang-tidy | iwyu | pch ] -D FILE="$(ItemPath)" -P "<Path-of-this-File>"
# - Initial Directory: $(SolutionDir)
# - Use Output Window: checked
#
# Usage: cmake
#        -D TOOL=<name>
#        -D FILE=<file>
#        -P run-clang-tools.cmake
#
cmake_minimum_required(VERSION 3.25 FATAL_ERROR)
foreach(arg TOOL FILE)
    if(NOT ${arg})
        message(FATAL_ERROR "${arg} is missing or empty")
    endif()
endforeach()

#
# Get location of presets file
#
cmake_path(CONVERT "${FILE}" TO_CMAKE_PATH_LIST FILE NORMALIZE)
cmake_path(RELATIVE_PATH FILE BASE_DIRECTORY "${CMAKE_SOURCE_DIR}" OUTPUT_VARIABLE file_in_solution)
cmake_path(GET FILE PARENT_PATH source_dir)

while(1)
    if(EXISTS "${source_dir}/CMakePresets.json")
        set(presets_path "${source_dir}")
    endif()
    if(EXISTS "${source_dir}/CMakeUserPresets.json")
        set(user_presets_path "${source_dir}")
    endif()
    if(source_dir PATH_EQUAL CMAKE_SOURCE_DIR OR (NOT "${presets_path}" STREQUAL "" AND NOT "${user_presets_path}" STREQUAL ""))
        break()
    endif()
    cmake_path(GET source_dir PARENT_PATH source_dir)
endwhile()
if(user_presets_path)
    set(source_dir "${user_presets_path}")
elseif(presets_path)
    set(source_dir "${presets_path}")
else()
    cmake_path(GET FILE PARENT_PATH source_dir)
    message(FATAL_ERROR "CMakePresets not found containing ${source_dir}")
endif()
cmake_path(RELATIVE_PATH FILE BASE_DIRECTORY "${source_dir}" OUTPUT_VARIABLE file)

#
# List presets
#
execute_process(COMMAND "${CMAKE_COMMAND}" --list-presets
                WORKING_DIRECTORY "${source_dir}"
                RESULT_VARIABLE result
                ERROR_VARIABLE error
                OUTPUT_VARIABLE configure_presets
                COMMAND_ECHO NONE)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "Error ${result}:\n${error}")
endif()

execute_process(COMMAND "${CMAKE_COMMAND}" --build --list-presets
                WORKING_DIRECTORY "${source_dir}"
                RESULT_VARIABLE result
                ERROR_VARIABLE error
                OUTPUT_VARIABLE build_presets
                COMMAND_ECHO NONE)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "Error ${result}:\n${error}")
endif()

#
# Get first configure preset with "debug", "dbug". "debg" or "dbg" in its name, first preset if debug preset not found
#
include("${CMAKE_CURRENT_LIST_DIR}/../modules/Regex.cmake")

foreach(type configure build)
    string(REPLACE ";" "\\;" ${type}_presets "${${type}_presets}")
    string(REPLACE "\n" ";" ${type}_presets "${${type}_presets}")
    list(FILTER ${type}_presets INCLUDE REGEX "^ +\".+\"")
    list(TRANSFORM ${type}_presets REPLACE "^ +\"(.+)\".*$" "\\1")

    if(type STREQUAL "configure")
        set(filtered_presets "${configure_presets}")
        #list(FILTER filtered_presets INCLUDE REGEX "[Dd][Ee]?[Bb][Uu]?[Gg]")
        list(FILTER filtered_presets INCLUDE REGEX "multi")
        if(filtered_presets)
            set(configure_presets "${filtered_presets}")
        endif()
        if(NOT configure_presets)
            message(FATAL_ERROR "No configure presets found in ${source_dir}")
        endif()
    else()
        regex_escape_pattern(configure_preset OUT configure_preset_pattern)
        list(FILTER build_presets INCLUDE REGEX "^${configure_preset_pattern}")

        set(filtered_presets "${build_presets}")
        list(FILTER filtered_presets INCLUDE REGEX "[Dd][Ee]?[Bb][Uu]?[Gg]")
        if(filtered_presets)
            set(build_presets "${filtered_presets}")
        endif()
        if(NOT build_presets)
            message(FATAL_ERROR "No build presets matching ${configure_preset} found in ${source_dir}")
        endif()
    endif()

    list(GET ${type}_presets 0 ${type}_preset)
endforeach()

#
# Get BINARY_DIR of preset
#
execute_process(COMMAND "${CMAKE_COMMAND}" --preset "${configure_preset}" -N
                WORKING_DIRECTORY "${source_dir}"
                RESULT_VARIABLE result
                ERROR_VARIABLE error
                OUTPUT_VARIABLE variables
                COMMAND_ECHO NONE)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "Error ${result}:\n${error}")
endif()

string(REPLACE ";" "\\;" variables "${variables}")
string(REPLACE "\n" ";" variables "${variables}")
list(FILTER variables INCLUDE REGEX "^ +BINARY_DIR=\".+\"$")
if(NOT variables)
    message(FATAL_ERROR "BUILD_ROOT not found in preset ${configure_preset} of ${source_dir}")
endif()

list(TRANSFORM variables REPLACE "^ +BINARY_DIR=\"(.+)\"$" "\\1")
list(GET variables 0 binary_dir)

message("Using configuration ${configure_preset} with binary dir ${binary_dir} and build ${build_preset}")

#
# Get target
#
file(READ "${binary_dir}/compile_commands.json" compile_commands)
string(JSON count LENGTH "${compile_commands}")
math(EXPR last_file "${count} - 1")

function(find_target input_file_path file)
    cmake_path(NORMAL_PATH input_file_path)
    string(TOLOWER "${input_file_path}" lower_input_file_path)
    foreach(index RANGE ${last_file})
        string(JSON file_path GET "${compile_commands}" ${index} "file")
        cmake_path(NORMAL_PATH file_path)
        string(TOLOWER "${file_path}" lower_file_path)
        cmake_path(COMPARE "${lower_input_file_path}" EQUAL "${lower_file_path}" is_equal)
        if(is_equal)
            string(JSON command GET "${compile_commands}" ${index} "command")
            cmake_path(GET file PARENT_PATH parent_folder)
            cmake_path(GET file FILENAME relative_file)
            unset(match)
            while(1)
                set(parent_with_slash "${parent_folder}")
                if(parent_with_slash)
                    string(APPEND parent_with_slash "/")
                endif()
                cmake_path(NATIVE_PATH parent_with_slash parent_native)
                cmake_path(NATIVE_PATH relative_file relative_file_native)
                regex_escape_pattern(parent_native OUT parent_pattern)
                regex_escape_pattern(relative_file_native OUT file_pattern)

                string(REGEX MATCH "-DCMAKE_INTDIR=\\\\\"(.+)\\\\\" " match "${command}")
                if(match)
                    # Multi-Config
                    set(config "${CMAKE_MATCH_1}")
                    regex_escape_pattern(config OUT config_pattern)
                    string(REGEX MATCH " /Fo(${parent_pattern}CMakeFiles\\\\(.+)\\.dir\\\\${config_pattern}\\\\${file_pattern}\\.obj) " match "${command}")
                    if(match)
                        set(config_subdir "${config}/" PARENT_SCOPE)
                        set(object "${CMAKE_MATCH_1}" PARENT_SCOPE)
                        set(target "${CMAKE_MATCH_2}" PARENT_SCOPE)
                        break()
                    endif()
                else()
                    # Non-Multi-Config
                    string(REGEX MATCH " /Fo(${parent_pattern}CMakeFiles\\\\(.+)\\.dir\\\\${file_pattern}\\.obj) " match "${command}")
                    if(match)
                        unset(config_subdir PARENT_SCOPE)
                        set(object "${CMAKE_MATCH_1}" PARENT_SCOPE)
                        set(target "${CMAKE_MATCH_2}" PARENT_SCOPE)
                        break()
                    endif()
                endif()
                if(NOT parent_folder)
                    break()
                endif()
                cmake_path(GET parent_folder FILENAME folder)
                cmake_path(REMOVE_FILENAME parent_folder)
                cmake_path(APPEND folder "${relative_file}" OUTPUT_VARIABLE relative_file)
            endwhile()
            break()
        endif()
    endforeach()
endfunction()

find_target("${FILE}" "${file}")
if(NOT target)
    # try to lookup source file when started with header file
    cmake_path(GET FILE FILENAME filename)
    unset(seen)
    list(APPEND seen "${filename}")
    foreach(extension "cpp" "c" "cc" "cxx" "c++" "C" "CPP" "cppm" "ixx" "M" "m" "mm" "mpp")
        cmake_path(REPLACE_EXTENSION filename LAST_ONLY "${extension}")
        if(NOT filename IN_LIST seen)
            file(GLOB_RECURSE glob LIST_DIRECTORIES false RELATIVE "${source_dir}" "${filename}")
            foreach(entry IN LISTS glob)
                cmake_path(ABSOLUTE_PATH entry BASE_DIRECTORY "${source_dir}" OUTPUT_VARIABLE entry_path)
                cmake_path(NATIVE_PATH entry_path entry_path)
                find_target("${entry_path}" "${entry}")
                if(target)
                    set(file "${entry}")
                    cmake_path(RELATIVE_PATH entry_path BASE_DIRECTORY "${CMAKE_SOURCE_DIR}" OUTPUT_VARIABLE file_in_solution)
                    break()
                endif()
            endforeach()
            if(target)
                break()
            endif()
        endif()
    endforeach()
    if(NOT target)
        message(FATAL_ERROR "${file} not found in compile_commands.json (${configure_preset})")
    endif()
endif()

#
# Run build
#

if(TOOL STREQUAL "compile")
    set(result_file "${object}")
elseif(TOOL MATCHES "^clang-tidy(.*)$")
    set(mode "${CMAKE_MATCH_1}")
    set(clang_tidy_checks "${binary_dir}/.clang-tools/.clang-tidy-checks")
    if(mode STREQUAL "-custom-set-config")
        # separate action to make launch of tool more responsive
        cmake_path(NATIVE_PATH clang_tidy_checks NORMALIZE clang_tidy_checks_native)
        execute_process(COMMAND "$ENV{COMSPEC}" /c "start" "clang-tidy Checks Override" "/wait"
                        "$ENV{COMSPEC}" /c "${CMAKE_CURRENT_LIST_DIR}/set-clang-tidy-config.bat" "${clang_tidy_checks_native}"
                        COMMAND_ECHO NONE)
        return()
    endif()
    if(mode STREQUAL "-custom" AND EXISTS "${clang_tidy_checks}")
        file(READ "${clang_tidy_checks}" checks)
        set(env_cmd "${CMAKE_COMMAND}" -E env "CMU_CLANG_TIDY_CHECKS=${checks}")
    endif()
    set(result_file ".clang-tools/${target}/${config_subdir}${file}.tidy")
elseif(TOOL STREQUAL "iwyu")
    set(result_file ".clang-tools/${target}/${config_subdir}${file}.iwyu")
elseif(TOOL STREQUAL "pch")
    set(result_file "./${config_subdir}pch-${target}.log")
else()
    message(FATAL_ERROR "Unknown tool: ${TOOL}")
endif()

execute_process(COMMAND ${env_cmd} "${CMAKE_COMMAND}" --build --preset "${build_preset}" --target "${result_file}"
                WORKING_DIRECTORY "${source_dir}"
                RESULTS_VARIABLE results
                OUTPUT_VARIABLE output
                ERROR_VARIABLE output
                COMMAND_ECHO NONE)

message(">------ ${file_in_solution} (${target}, ${build_preset}) - ${binary_dir} ------\n")
if(results)
    message("Result ${results}:\n${output}")
    message(FATAL_ERROR "Error running build: ${result_file}")
endif()

if(TOOL STREQUAL "compile")
    message("Done.")
    return()
endif()

#
# Post-process output (in format for Visual Studio)
#

file(READ "${binary_dir}/${result_file}" output)
string(REPLACE ";" "\\;" output "${output}")
string(REPLACE "\n" ";" output "${output}")
unset(result)
if(TOOL MATCHES "^clang-tidy.*")
    foreach(line IN LISTS output)
        string(REGEX MATCH "^([^ ].+):([0-9]+):([0-9]+): ([^ ]+): (.+) \\[(.+)\\]$" parts "${line}")
        if(parts)
            cmake_path(NATIVE_PATH CMAKE_MATCH_1 native)
            set(line "${native}(${CMAKE_MATCH_2},${CMAKE_MATCH_3}): ${CMAKE_MATCH_4} [${CMAKE_MATCH_6}]: ${CMAKE_MATCH_5}")
        endif()
        string(REPLACE ";" "\\;" line "${line}")
        list(APPEND result "${line}")
    endforeach()
elseif(TOOL STREQUAL "iwyu" OR TOOL STREQUAL "pch")
    foreach(line IN LISTS output)
        string(REGEX MATCH "^([^ ].+)( should.+$)" parts "${line}")
        if(parts)
            cmake_path(NATIVE_PATH CMAKE_MATCH_1 native)
            set(line "${native}:${CMAKE_MATCH_2}")
        else()
            string(REGEX MATCH "^\\((.+)( has correct.+)\\)$" parts "${line}")
            if(parts)
                cmake_path(NATIVE_PATH CMAKE_MATCH_1 native)
                set(line "${native}:${CMAKE_MATCH_2}")
            else()
                string(REGEX MATCH "^(The full include-list) for (.+):$" parts "${line}")
                if(parts)
                    cmake_path(NATIVE_PATH CMAKE_MATCH_2 native)
                    set(line "${native}: ${CMAKE_MATCH_1}:")
                endif()
            endif()
        endif()
        string(REPLACE ";" "\\;" line "${line}")
        list(APPEND result "${line}")
    endforeach()
endif()
list(JOIN result "\n" result)
string(REPLACE "\\;" ";" output "${result}")
message("${output}")
