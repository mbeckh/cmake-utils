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
# Output result files to stderr using shell formatting.
# Usage: cmake
#        -D TOOL=<name>
#        -D SOURCE_DIR=<path>
#        .D FILES=<file>;...
#        -P cat-result.cmake
#
cmake_minimum_required(VERSION 3.25 FATAL_ERROR)

foreach(arg TOOL SOURCE_DIR FILES)
    if(NOT ${arg})
        message(FATAL_ERROR "${arg} is missing or empty")
    endif()
endforeach()

#https://en.wikipedia.org/wiki/ANSI_escape_code
string(ASCII 27 esc)
set(fmt_off "${esc}[m")
set(fmt_ok "${esc}[97m")
set(fmt_error "${esc}[93m")
set(fmt_text "${esc}[96m")
set(fmt_rule "${esc}[95m")

foreach(input IN LISTS FILES)
    file(STRINGS "${input}" content)

    if(TOOL STREQUAL "iwyu" OR TOOL STREQUAL "pch")
        foreach(line IN LISTS content)
            if(line MATCHES "^(\\()(.+)( has correct.*)$")
                cmake_path(RELATIVE_PATH CMAKE_MATCH_2 BASE_DIRECTORY "${SOURCE_DIR}" OUTPUT_VARIABLE path)
                message("${CMAKE_MATCH_1}${fmt_ok}${path}${fmt_text}${CMAKE_MATCH_3}${fmt_off}")
            elseif(line MATCHES "^(.+)( should.*)$")
                cmake_path(RELATIVE_PATH CMAKE_MATCH_1 BASE_DIRECTORY "${SOURCE_DIR}" OUTPUT_VARIABLE path)
                message("${fmt_error}${path}${fmt_text}${CMAKE_MATCH_2}${fmt_off}")
            elseif(line MATCHES "^(The full include-list for )(.+)(:)$")
                cmake_path(RELATIVE_PATH CMAKE_MATCH_2 BASE_DIRECTORY "${SOURCE_DIR}" OUTPUT_VARIABLE path)
                message("${fmt_text}${CMAKE_MATCH_1}${fmt_error}${path}${fmt_text}${CMAKE_MATCH_3}${fmt_off}")
            elseif(line MATCHES "^(.+):$")
                message("${fmt_ok}${CMAKE_MATCH_1}:${fmt_off}")
            else()
                message("${line}")
            endif()
        endforeach()
    elseif(TOOL STREQUAL "clang-tidy")
        foreach(line IN LISTS content)
            if(line MATCHES "^([^ ].*:[0-9]+:[0-9]+)(: .*)(\\[.+\\])$")
                cmake_path(RELATIVE_PATH CMAKE_MATCH_1 BASE_DIRECTORY "${SOURCE_DIR}" OUTPUT_VARIABLE path)
                message("${fmt_error}${path}${fmt_text}${CMAKE_MATCH_2}${fmt_rule}${CMAKE_MATCH_3}${fmt_off}")
            else()
                message("${line}")
            endif()
        endforeach()
    else()
        message(FATAL_ERROR "Unknown tool: ${TOOL}")
    endif()
endforeach()
