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
# Concatenate files to stderr or file.
# Usage: cmake
#        [ -D TOOL ]
#        [ -D COLOR=<color> | -D OUTPUT=<file> ]
#        -D FILES=<file>;...
#        [ -D FILES_DIR=<path> ]
#        -P cat.cmake
# Note: cmake -E cat Does not work: Stops on empty file as of CMake 3.20.0.
#
cmake_minimum_required(VERSION 3.25 FATAL_ERROR)

foreach(arg FILES)
    if(NOT ${arg})
        message(FATAL_ERROR "${arg} is missing or empty")
    endif()
endforeach()

if(OUTPUT)
    if(COLOR)
        message(FATAL_ERROR "Cannot use OUTPUT and COLOR at the same time")
    endif()
    file(REMOVE "${OUTPUT}")
endif()

if(COLOR STREQUAL "cyan")
    string(ASCII 27 esc)
    message("${esc}[96m")
endif()

function(clang_tidy_unique var messages)
    unset(result)
    unset(entry)
    foreach(message IN LISTS messages)
        string(REPLACE ";" "\\\\;" message "${message}")
        if(message MATCHES [[^.+:[0-9]+:[0-9]+: [a-z]+: .+ \[[a-z0-9,-]+\]$]])
            if(entry)
                list(APPEND result "${entry}")
            endif()
            set(entry "${message}")
        else()
            string(APPEND entry "\n" "${message}")
        endif()
    endforeach()
    if(entry)
        list(APPEND result "${entry}")
    endif()

    list(REMOVE_DUPLICATES result)
    list(JOIN result "\n" result)
    set("${var}" "${result}" PARENT_SCOPE)
endfunction()

if(TOOL STREQUAL "clang-tidy")
    unset(messages)
    foreach(file IN LISTS FILES)
        file(STRINGS "${file}" contents)
        list(APPEND messages "${contents}")
    endforeach()

    clang_tidy_unique(contents "${messages}")

    if(OUTPUT)
        file(WRITE "${OUTPUT}" "${contents}")
    else()
        message("${contents}")
    endif()
elseif(TOOL STREQUAL "iwyu")
    unset(messages)
    foreach(file IN LISTS FILES)
        file(READ "${file}" contents)

        # convert entries for files into items of a CMake list
        string(REPLACE ";" "\\;" contents "${contents}")
        string(REGEX REPLACE "\n---\n" "\n---;" contents "${contents}")
        list(TRANSFORM contents STRIP)
        list(REMOVE_ITEM contents "")

        cmake_path(REMOVE_EXTENSION file LAST_ONLY)
        cmake_path(RELATIVE_PATH file BASE_DIRECTORY "${FILES_DIR}")
        list(APPEND messages "\n${file}:" "${contents}")
    endforeach()

    # Only keep first entry for files which have been processed more than once
    list(REMOVE_DUPLICATES messages)
    # Create contiguous output
    list(JOIN messages "\n\n" messages)

    if(OUTPUT)
        file(APPEND "${OUTPUT}" "${messages}")
    else()
        message("${messages}")
    endif()
else()
    foreach(file IN LISTS FILES)
        file(READ "${file}" contents)
        if(OUTPUT)
            file(APPEND "${OUTPUT}" "${contents}")
        else()
            message("${contents}")
        endif()
    endforeach()
endif()

if(COLOR)
    message("${esc}[m")
endif()
