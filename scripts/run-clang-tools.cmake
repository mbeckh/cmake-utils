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
cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

cmake_path(RELATIVE_PATH FILE BASE_DIRECTORY "${CMAKE_SOURCE_DIR}" OUTPUT_VARIABLE file_in_solution)
cmake_path(GET FILE PARENT_PATH solution_dir)
cmake_path(GET FILE ROOT_PATH root_path)
while(NOT solution_dir STREQUAL root_path AND NOT EXISTS "${solution_dir}/CMakeSettings.json")
    cmake_path(GET solution_dir PARENT_PATH solution_dir)
endwhile()

if(NOT EXISTS "${solution_dir}/CMakeSettings.json")
    message(FATAL_ERROR "CMake project not found containing ${CMAKE_BINARY_DIR}")
endif()
cmake_path(RELATIVE_PATH FILE BASE_DIRECTORY "${solution_dir}" OUTPUT_VARIABLE file)

file(READ "${solution_dir}/CMakeSettings.json" settings)

#
# Get first Debug configuration
#
string(JSON count LENGTH "${settings}" "configurations")
math(EXPR last_configuration "${count} - 1")
foreach(index RANGE ${last_configuration})
    string(JSON configurationName GET "${settings}" configurations ${index} "name")
    string(JSON configurationType GET "${settings}" configurations ${index} "configurationType")
    if(NOT build_root OR configurationType STREQUAL Debug)
        string(JSON build_root GET "${settings}" configurations ${index} "buildRoot")
        if(configurationType STREQUAL Debug)
            break()
        endif()
    endif()
endforeach()

#
# Get build path
#
function(replace_variables str)
    set(result "${${str}}")

    string(REGEX MATCHALL [[\${[^}]+}]] variables "${result}")
    if(variables)
        string(JSON count LENGTH "${settings}" environments)
        math(EXPR lastEnvironment "${count} - 1")
    endif()
    
    foreach(variable IN LISTS variables)
        string(REGEX MATCH [[\${(([^.}]+)\.)?([^.}]+)}]] parts "${variable}")
        set(prefix "${CMAKE_MATCH_2}")
        set(name "${CMAKE_MATCH_3}")

        unset(found)
        if(prefix)
            foreach(index RANGE ${lastEnvironment})
                string(JSON namespace ERROR_VARIABLE error GET "${settings}" environments ${index} namespace)
                if((prefix STREQUAL "env" AND NOT namespace) OR prefix STREQUAL namespace)
                    string(JSON value GET "${settings}" environments ${index} "${name}")
                    replace_variables(value)
                    string(REPLACE "${variable}" "${value}" result "${result}")
                    set(found YES)
                    break()
                endif()
            endforeach()
        elseif(name STREQUAL "name")
            string(REPLACE "${variable}" "${configurationName}" result "${result}")
            set(found YES)
        elseif(name STREQUAL "projectDirName")
            cmake_path(GET solution_dir FILENAME project_dir_name)
            string(REPLACE "${variable}" "${project_dir_name}" result "${result}")
            set(found YES)
        endif()
        if(NOT found)
            message(FATAL_ERROR "Unknown replacement: ${parts} in ${${str}}")
        endif()
    endforeach()

    set("${str}" "${result}" PARENT_SCOPE)
endfunction()

replace_variables(build_root)

#
# Get target
#
include("${CMAKE_CURRENT_LIST_DIR}/../modules/Regex.cmake")

file(READ "${build_root}/compile_commands.json" compile_commands)
string(JSON count LENGTH "${compile_commands}")
math(EXPR last_file "${count} - 1")

function(find_target FILE file)
    cmake_path(NORMAL_PATH FILE OUTPUT_VARIABLE input_file_path)
    string(TOLOWER "${input_file_path}" lower_input_file_path)
    foreach(index RANGE ${last_file})
        string(JSON file_path GET "${compile_commands}" ${index} "file")
        cmake_path(NORMAL_PATH file_path)
        string(TOLOWER "${file_path}" lower_file_path)
        cmake_path(COMPARE "${lower_input_file_path}" EQUAL "${lower_file_path}" is_equal)
        if(is_equal)
            string(JSON command GET "${compile_commands}" ${index} "command")
            cmake_path(NATIVE_PATH file relative_file_path)
            regex_escape_pattern(relative_file_path)
            string(REGEX MATCH " /Fo(CMakeFiles\\\\(.+)\\.dir\\\\${relative_file_path}\\.obj) " match "${command}")
            if(match)
                set(target "${CMAKE_MATCH_2}" PARENT_SCOPE)
                set(object "${CMAKE_MATCH_1}" PARENT_SCOPE)
            endif()
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
    foreach(extension "cpp" "c" "cc" "cxx" "c++" "C")
        cmake_path(REPLACE_EXTENSION filename LAST_ONLY "${extension}")
        if(NOT filename IN_LIST seen)
            file(GLOB_RECURSE glob LIST_DIRECTORIES false RELATIVE "${solution_dir}" "${filename}")
            foreach(entry IN LISTS glob)
                cmake_path(ABSOLUTE_PATH entry BASE_DIRECTORY "${solution_dir}" OUTPUT_VARIABLE entry_path)
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
        message(FATAL_ERROR "${file} not found in compile_commands.json")
    endif()
endif()

#
# Run build
#

if(TOOL STREQUAL "compile")
    set(result_file "${object}")
elseif(TOOL STREQUAL "clang-tidy")
    set(result_file ".clang-tools/${target}/${file}.tidy")
elseif(TOOL STREQUAL "iwyu")
    set(result_file ".clang-tools/${target}/${file}.iwyu")
elseif(TOOL STREQUAL "pch")
    set(result_file "./pch-${target}.log")
else()
    message(FATAL_ERROR "Unknown tool: ${TOOL}")
endif()

execute_process(COMMAND "${CMAKE_COMMAND}" --build . --target "${result_file}"
                WORKING_DIRECTORY "${build_root}"
                RESULTS_VARIABLE results
                OUTPUT_VARIABLE output
                ERROR_VARIABLE output
                COMMAND_ECHO NONE
                )

message(">------ ${file_in_solution} (${target}, ${configurationName}) - ${build_root} ------\n")
if(results)
    message("Result ${results}:\n${output}")
    message(FATAL_ERROR "Error running build: ${result_file}")
endif()

if(TOOL STREQUAL "compile")
    message("Done.")
    return()
endif()

#
# Post-process output
#

file(READ "${build_root}/${result_file}" output)
string(REPLACE ";" "\\;" output "${output}")
string(REPLACE "\n" ";" output "${output}")
unset(result)
if(TOOL STREQUAL clang-tidy)
    foreach(line IN LISTS output)
        string(REGEX MATCH "^([^ ].+):([0-9]+):([0-9]+): ([^ ]+): (.+) \\[(.+)\\]$" parts "${line}")
        if(parts)
            cmake_path(NATIVE_PATH CMAKE_MATCH_1 native)
            set(line "${native}(${CMAKE_MATCH_2},${CMAKE_MATCH_3}): ${CMAKE_MATCH_4} [${CMAKE_MATCH_6}]: ${CMAKE_MATCH_5}")
        endif()
        string(REPLACE ";" "\\;" line "${line}")
        list(APPEND result "${line}")
    endforeach()
elseif(TOOL STREQUAL iwyu OR TOOL STREQUAL pch)
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
