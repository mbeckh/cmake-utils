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
# Separate main from auxiliary includes for running clang-tidy and include-what-you-use.
# Usage: cmake
#        -D CMAKE_MAKE_PROGRAM=<file>
#        -D TARGET=<name>
#        -D SOURCE_DIR=<path>
#        -D BINARY_DIR=<path>
#        -D SOURCES=<file>;...
#        -D INCLUDES=<file>;...
#        -D AUX_INCLUDES=<file>;...
#        -D LIBRARIES=<name>;...
#        -D LIBRARIES_INCLUDES=<file>;...
#        -D OUTPUTS=<file>;...
#        [ -D ARGUMENTS=<file> ]
#        -P aux-includes.cmake
#
cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

include("${CMAKE_CURRENT_LIST_DIR}/../Regex.cmake")

# Allow arguments from include instead of command line
if(ARGUMENTS)
    include("${ARGUMENTS}")
endif()

# Read dependencies
execute_process(COMMAND "${CMAKE_MAKE_PROGRAM}" -t deps
                RESULT_VARIABLE result
                OUTPUT_VARIABLE dependencies
                ERROR_VARIABLE error
                COMMAND_ECHO NONE)
if(result)
    message(FATAL_ERROR "Error ${result}:\n${error}")
endif()

regex_escape_replacement(SOURCE_DIR OUT replacement)
# remove comments
string(REGEX REPLACE "(^|\n)CMakeFiles/[^/\n]+/([^:\n]*)\\.[^.:\n]*: #[^\n]*" "${replacement}/\\2:\t" dependencies "${dependencies}")
# cannot reference optional group in replacement
string(REGEX REPLACE "(^|\n)([^:\n]+/)CMakeFiles/[^/\n]+/([^:\n]*)\\.[^.:\n]*: #[^\n]*" "${replacement}/\\2\\3:\t" dependencies "${dependencies}")
# place all headers on a single line
string(REGEX REPLACE "\n+ +" "\t" dependencies "${dependencies}")
# remove empty lines
string(REGEX REPLACE "\n\n+" "\n" dependencies "${dependencies}")
# remove double whitespace and convert all spaces to tabs
string(REGEX REPLACE "[ \t][ \t]*" "\t" dependencies "${dependencies}")
# escape semicolons
string(REPLACE ";" "\\;" dependencies "${dependencies}")
# split into list, one item per source file
string(REPLACE "\n" ";" dependencies "${dependencies}")
# remove empty entries
list(FILTER dependencies EXCLUDE REGEX "^ *\$")

# Make all paths absolute
unset(result)
foreach(entry IN LISTS dependencies)
    string(REGEX MATCH "^([^\t\n]+):\t([^\n]*)" source "${entry}")
    if(NOT source)
        message(FATAL_ERROR "Error matching source: ${entry}")
    endif()
    set(includes "${CMAKE_MATCH_2}")
    cmake_path(ABSOLUTE_PATH CMAKE_MATCH_1 NORMALIZE OUTPUT_VARIABLE source)
    string(REPLACE ";" "\\;" source "${source}")
    set(line "${source}:")

    string(REGEX MATCHALL "[^\t\n]+([\t\n]|\$)" includes "${includes}")
    foreach(include IN LISTS includes)
        string(REGEX MATCH "^([^\t\n]+)([\t\n]|\$)" match "${include}")
        if(NOT match)
            message(FATAL_ERROR "Error matching include: ${include}")
        endif()
        cmake_path(ABSOLUTE_PATH CMAKE_MATCH_1 NORMALIZE OUTPUT_VARIABLE include)
        string(REPLACE ";" "\\;" include "${include}")
        list(APPEND line "${include}")
    endforeach()
    list(JOIN line "\t" line)
    list(APPEND result "${line}")
endforeach()
set(dependencies "${result}")


# Get a list of all includes from dep file
foreach(source IN LISTS SOURCES)
    set(entries "${dependencies}")

    # Filter by source file
    regex_escape_pattern(source OUT pattern)
    list(FILTER entries INCLUDE REGEX "^${pattern}:(\t|$)")
    # Get headers only
    list(TRANSFORM entries REPLACE "^${pattern}:(\t|$)" "")

    # Add tab-separated list of includes
    if(entries)
        list(APPEND unseen_includes "${entries}")
    endif()
endforeach()

# Build a single string
list(JOIN unseen_includes "\t" unseen_includes)

# Convert to list
string(REPLACE "\t" ";" unseen_includes "${unseen_includes}")
list(TRANSFORM unseen_includes STRIP)

# Remove known includes
list(REMOVE_ITEM unseen_includes ${INCLUDES})

# Restrict to unseen_includes in or below source directory
regex_escape_pattern(SOURCE_DIR OUT pattern)
list(FILTER unseen_includes INCLUDE REGEX "^${pattern}/")
# Account for case where binary directory is sub directory of source directory
regex_escape_pattern(BINARY_DIR OUT pattern)
list(FILTER unseen_includes EXCLUDE REGEX "^${pattern}/")
# Unique entries only
list(REMOVE_DUPLICATES unseen_includes)

# Get first source file for each auxiliary include
foreach(include IN LISTS AUX_INCLUDES)
    set(candidates "${dependencies}")

    regex_escape_pattern(include OUT pattern)
    list(FILTER candidates INCLUDE REGEX "\t+${pattern}(\t|$)")
    list(TRANSFORM candidates REPLACE "^([^\t]+):(\t.*|$)" "\\1")
    list(SORT candidates CASE INSENSITIVE)

    unset(file)
    foreach(candidate IN LISTS candidates)
        if(candidate IN_LIST SOURCES)
            set(file "${candidate}")
            break()
        endif()
    endforeach()
    if(NOT file)
        string(ASCII 27 esc)
        message(STATUS "${esc}[95mUnused include in target ${TARGET}: ${include}${esc}[m")
    endif()
    string(APPEND mapping "${file}\t${include}\n")

    list(REMOVE_ITEM unseen_includes "${include}")
endforeach()

# Remove any includes from libraries
foreach(include IN LISTS LIBRARIES_INCLUDES)
    include("${include}")
endforeach()

foreach(library IN LISTS LIBRARIES)
    foreach(include IN LISTS ${library}_INCLUDES)
        list(REMOVE_ITEM unseen_includes "${include}")
    endforeach()
endforeach()

# Report any includes not part of add_library/add_executable calls
if(unseen_includes)
    list(LENGTH unseen_includes count)
    foreach(index RANGE 1 ${count})
        list(POP_FRONT unseen_includes file)
        cmake_path(RELATIVE_PATH file BASE_DIRECTORY "${SOURCE_DIR}")
        string(REPLACE ";" "\\;" file "${file}")
        list(APPEND unseen_includes "${file}")
    endforeach()
    list(SORT unseen_includes CASE INSENSITIVE)
    list(JOIN unseen_includes " " unseen_includes)
    string(ASCII 27 esc)
    message(FATAL_ERROR "${esc}[95mUndeclared include in target ${TARGET}: ${unseen_includes}${esc}[m")
endif()

# Write .auxi file for each source
foreach(source output IN ZIP_LISTS SOURCES OUTPUTS)
    set(entries "${mapping}")

    regex_escape_pattern(source OUT pattern)
    list(FILTER entries INCLUDE REGEX "${pattern}\t")

    # Get all headers of source
    list(TRANSFORM entries REPLACE "${pattern}\t" "")
    list(SORT entries CASE INSENSITIVE)
    list(JOIN entries "\n" contents)

    if(EXISTS "${output}")
        file(SHA1 "${output}" file_hash)
        string(SHA1 string_hash "${contents}")

        string(COMPARE NOTEQUAL "${file_hash}" "${string_hash}" update)
    else()
        set(update YES)
    endif()
    if(update)
        file(WRITE "${output}" "${contents}")
    endif()
endforeach()

# Mark completion
file(TOUCH ".clang-tools/${TARGET}/.aux-includes")
