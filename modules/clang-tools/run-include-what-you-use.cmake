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
# Run include-what-you-use for input adding --check_also for auxiliary includes.
# Usage: cmake
#        -D Python_EXECUTABLE=<file>
#        -D include-what-you-use_PY=<file>
#        [ -D include-what-you-use_MAPPING_FILES=<file>;... ]
#        -D COMPILE_COMMANDS_PATH=<path>
#        -D FILES=<file>;...
#        -D OUTPUT=<file>
#        -P run-include-what-you-use.cmake
#
cmake_minimum_required(VERSION 3.25 FATAL_ERROR)

foreach(arg Python_EXECUTABLE include-what-you-use_PY COMPILE_COMMANDS_PATH FILES OUTPUT)
    if(NOT ${arg})
        message(FATAL_ERROR "${arg} is missing or empty")
    endif()
endforeach()

include("${CMAKE_CURRENT_LIST_DIR}/../Regex.cmake")

# Get all includes of file
cmake_path(REPLACE_EXTENSION OUTPUT LAST_ONLY ".inc" OUTPUT_VARIABLE includes_file)
file(STRINGS "${includes_file}" includes REGEX "U\\|")
list(TRANSFORM includes REPLACE "^U\\|" "")

# Remove all includes which are "main" includes of other source files"
file(STRINGS "${COMPILE_COMMANDS_PATH}.sources" sources)
foreach(source IN LISTS sources)
    cmake_path(GET source STEM LAST_ONLY base_name)
    string(REGEX REPLACE "([_.](unit|reg)?test)|(-inl)$" "" canonical_base_name "${base_name}")
    regex_escape_pattern(base_name)
    regex_escape_pattern(canonical_base_name)

    list(FILTER includes EXCLUDE REGEX "(^|.+/)(${base_name}|${canonical_base_name})\\.(h|H|hpp|hxx|hh|inl)$")
endforeach()

list(SORT includes CASE INSENSITIVE)
list(REMOVE_DUPLICATES includes)
list(TRANSFORM includes PREPEND "--check_also=")

# Options for additional mapping files
if(include-what-you-use_MAPPING_FILES)
    list(TRANSFORM include-what-you-use_MAPPING_FILES PREPEND "--mapping_file=")
    list(APPEND options "${include-what-you-use_MAPPING_FILES}")
endif()
list(APPEND options "--mapping_file=${CMAKE_CURRENT_LIST_DIR}/msvc.imp"
                    --verbose=2 --update_comments --quoted_includes_first --cxx17ns --max_line_length=256)
if(includes)
    list(APPEND options "${includes}")
endif()

list(LENGTH options stop)
math(EXPR stop "${stop} - 1")
foreach(index RANGE 0 ${stop})
    math(EXPR pos "${index} * 2")
    list(INSERT options ${pos} -Xiwyu)
endforeach()

execute_process(COMMAND "${Python_EXECUTABLE}" "${include-what-you-use_PY}" -p "${COMPILE_COMMANDS_PATH}" ${FILES} --
                        ${options}
                        -Wno-unknown-attributes
                RESULT_VARIABLE result
                ERROR_VARIABLE error
                OUTPUT_VARIABLE output
                COMMAND_ECHO NONE)
# IWYU returns 1 as result when no errors happened
if(NOT result EQUAL 0 AND NOT result EQUAL 1)
    message(FATAL_ERROR "Error ${result}:\n${error}")
endif()

string(REPLACE "\r" "" output "${output}")
file(WRITE "${OUTPUT}" "${output}")
