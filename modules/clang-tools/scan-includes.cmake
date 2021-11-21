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
# Detect all system includes for a source file or precompiled header.
# Usage: cmake
#        -D CLANG=<file>
#        -D TARGET=<name>
#        -D PROJECT_SOURCE_DIR=<path>
#        -D PROJECT_BINARY_DIR=<path>
#        -D BINARY_DIR=<path>
#        [ -D FILES=<file>;... | -D PCH=<language> ]
#        -D OUTPUT=<file>
#        -P scan-includes.cmake
#
cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

if(NOT FILES AND NOT PCH)
    message(FATAL_ERROR "No input files or PCH")
endif()

file(READ ".clang-tools/${TARGET}/compile_commands.json" compile_commands)
string(JSON count LENGTH "${compile_commands}")
math(EXPR count "${count} - 1")

set(default_system_include_path $ENV{INCLUDE})

if(PCH)
    include("${CMAKE_CURRENT_LIST_DIR}/../Regex.cmake")

    regex_escape_pattern(BINARY_DIR OUT binary_dir_pattern)
    regex_escape_pattern(TARGET OUT target_pattern)
    set(pch_source_pattern "^${binary_dir_pattern}/CMakeFiles/${target_pattern}\\.dir/cmake_pch\\.c(.+)$")
endif()

set(vcpkg_build_dir "${PROJECT_BINARY_DIR}/vcpkg_installed/")

foreach(i RANGE ${count})
    string(JSON file GET "${compile_commands}" ${i} "file")

    cmake_path(CONVERT "${file}" TO_CMAKE_PATH_LIST file)
    if(FILES)
        list(FIND FILES "${file}" index)
        if(index EQUAL -1)
            continue()
        endif()
        list(REMOVE_AT FILES ${index})
    elseif(PCH)
        if(NOT file MATCHES "${pch_source_pattern}")
            continue()
        endif()
    endif()

    string(JSON command GET "${compile_commands}" ${i} "command")
    string(JSON directory GET "${compile_commands}" ${i} "directory")

    separate_arguments(command NATIVE_COMMAND "${command}")
    list(FILTER command EXCLUDE REGEX "^[/-](((Y[cu]|F[dopI]).*)|c|MP|ZI)$")
    if(PCH)
        # parse header instead of source because dumping includes does not work for includes added using -include
        string(REPLACE "cmake_pch.c${CMAKE_MATCH_1}" "cmake_pch.h${CMAKE_MATCH_1}" command "${command}")
    endif()
    list(INSERT command 1 /EP /showIncludes /clang:-fshow-skipped-includes /clang:-Qunused-arguments /clang:-Wno-pragma-system-header-outside-header)
    list(POP_FRONT command)
    list(PREPEND command "${CLANG}" --driver-mode=cl)

    execute_process(COMMAND ${command}
                    WORKING_DIRECTORY "${directory}"
                    RESULT_VARIABLE result
                    ERROR_VARIABLE results
                    OUTPUT_QUIET
                    COMMAND_ECHO NONE)
    if(result)
        message(FATAL_ERROR "Error ${result}:\n${results}")
    endif()

    string(REPLACE ";" "\\;" results "${results}")
    string(REGEX REPLACE "[\r\n]+" ";" results "${results}")
    list(LENGTH results l)
    list(FILTER results INCLUDE REGEX "^Note: including file:")
    list(LENGTH results l)
    list(TRANSFORM results REPLACE "^Note: including file: " "")

    set(system_include_path "${default_system_include_path}")
    list(FILTER command INCLUDE REGEX "^/clang:-isystem")
    list(TRANSFORM command REPLACE "/clang:-isystem" "")
    if(command)
        list(APPEND system_include_path "${command}")
    endif()

    set(ignore "-")
    unset(includes)
    while(results)
        list(POP_FRONT results item)
        string(STRIP "${item}" file)
        if(NOT ignore STREQUAL "-" AND item MATCHES "^${ignore} ")
            continue()
        endif()

        cmake_path(CONVERT "${file}" TO_CMAKE_PATH_LIST file NORMALIZE)
        cmake_path(IS_PREFIX PROJECT_SOURCE_DIR "${file}" NORMALIZE prefix_source)
        cmake_path(IS_PREFIX BINARY_DIR "${file}" NORMALIZE prefix_binary)
        cmake_path(IS_PREFIX vcpkg_build_dir "${file}" NORMALIZE prefix_vcpkg)
        if(prefix_source AND NOT prefix_binary)
            set(ignore "-")
        elseif(prefix_binary AND NOT prefix_vcpkg)
            set(ignore "-")
        else()
            foreach(system_include IN LISTS system_include_path)
                cmake_path(CONVERT "${system_include}" TO_CMAKE_PATH_LIST system_include)
                cmake_path(IS_PREFIX system_include "${file}" NORMALIZE prefix)
                if(prefix)
                    cmake_path(RELATIVE_PATH file BASE_DIRECTORY "${system_include}")
                    break()
                endif()
            endforeach()
            string(REGEX MATCH "^ +" ignore "${item}")
            string(REPLACE ";" "\\;" file "${file}")
            list(APPEND includes "${file}")
        endif()
    endwhile()

    if(NOT FILES AND NOT PCH)
        break()
    endif()
endforeach()

list(SORT includes CASE INSENSITIVE)
list(REMOVE_DUPLICATES includes)
list(JOIN includes "\n" includes)

file(WRITE "${OUTPUT}" "${includes}")
