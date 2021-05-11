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
# Run clang-tidy for input adding --header-filter for main and auxiliary includes.
# Usage: cmake
#        -D MSVC_VERSION=<version>
#        -D clang-tidy_EXE=<file>
#        -D TARGET=<name>
#        -D INCLUDES=<file>;...
#        -D FILES=<file>;...
#        -D AUX_INCLUDES_FILES=<file>;...
#        -D OUTPUT=<file>
#        -P run-clang-tidy.cmake
#
cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

include("${CMAKE_CURRENT_LIST_DIR}/../Regex.cmake")

if(NOT FILES)
    message(FATAL_ERROR "No input files")
endif()
if(NOT OUTPUT)
    message(FATAL_ERROR "No output file")
endif()

foreach(file aux_includes_file IN ZIP_LISTS FILES AUX_INCLUDES_FILES)
    if(NOT EXISTS "${aux_includes_file}")
        message(FATAL_ERROR "Include analysis missing: ${aux_includes_file}")
    endif()
    file(STRINGS "${aux_includes_file}" entries)
    if(entries)
        list(APPEND aux_includes "${entries}")
    endif()

    cmake_path(GET file STEM LAST_ONLY base_name)
    string(REGEX REPLACE "(_(unit|reg)?test)|(-inl)$" "" canonical_base_name "${base_name}")
    string(REPLACE ";" "\\;" base_name "${base_name}")
    string(REPLACE ";" "\\;" canonical_base_name "${canonical_base_name}")
    list(APPEND pattern "${base_name}" "${canonical_base_name}")
endforeach()
list(SORT aux_includes CASE INSENSITIVE)
list(REMOVE_DUPLICATES aux_includes)

list(REMOVE_DUPLICATES pattern)
regex_escape_pattern(pattern)
list(JOIN pattern "|" pattern)

set(header_filter "${INCLUDES}")
list(FILTER header_filter INCLUDE REGEX "(^|.+/)(${pattern})\\.(h|H|hpp|hxx|hh|inl)$")
if(aux_includes)
    list(APPEND header_filter "${aux_includes}")
endif()

if(header_filter)
    list(TRANSFORM header_filter REPLACE "^.*/([^/]+)$" "\\1")
    regex_escape_pattern(header_filter)
    list(JOIN header_filter "|" header_filter)
    string(PREPEND header_filter "--header-filter=(^|.+/)(")
    string(APPEND header_filter ")\$")
endif()

execute_process(COMMAND "${clang-tidy_EXE}" -p .clang-tools
                        "--extra-arg=-fmsc-version=${MSVC_VERSION}"
                        ${header_filter}
                        ${FILES}
                RESULT_VARIABLE result
                ERROR_VARIABLE error
                OUTPUT_FILE "${OUTPUT}"
                COMMAND_ECHO NONE)
if(result)
    message(FATAL_ERROR "Error ${result}:\n${error}")
endif()
