#
# Separate main from auxiliary includes for running clang-tidy and include-what-you-use.
# Usage: cmake
#        -D CMAKE_MAKE_PROGRAM=<file>
#        -D TARGET=<name>
#        -D SOURCE_DIR=<path>
#        -D SOURCES=<file>;...
#        -D INCLUDES=<file>;...
#        -D OUTPUTS=<file>;...
#        -P aux-includes.cmake
#
# MIT License, Copyright (c) 2021 Michael Beckh, see LICENSE
#
cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

include("${CMAKE_CURRENT_LIST_DIR}/regex.cmake")

# Read dependencies
execute_process(COMMAND "${CMAKE_MAKE_PROGRAM}" -t deps
                RESULT_VARIABLE result
                OUTPUT_VARIABLE dependencies
                ERROR_VARIABLE error
                COMMAND_ECHO NONE)
if(result)
    message(FATAL_ERROR "Error ${result}:\n${error}")
endif()

clang_tools_regex_escape_replacement(SOURCE_DIR OUT replacement)
# remove comments
string(REGEX REPLACE "(^|\n)CMakeFiles/[^/\n]+/([^:\n]*)\\.[^.:\n]*: #[^\n]*" "${replacement}/\\2:\t" dependencies "${dependencies}")
# cannot reference optional group in replacement
string(REGEX REPLACE "(^|\n)([^:\n]+/)CMakeFiles/[^/\n]+/([^:\n]*)\\.[^.:\n]*: #[^\n]*" "${replacement}/\\2\\3:\t" dependencies "${dependencies}")
# place all headers on a single line
string(REGEX REPLACE "\n+ +" "\t" dependencies "${dependencies}")
# remove empty lines
string(REGEX REPLACE "\n\n+" "\n" dependencies "${dependencies}")
# remove double whitespace
string(REGEX REPLACE "[ \t][ \t]+" "\t" dependencies "${dependencies}")
# escape semicolons
string(REPLACE ";" "\\;" dependencies "${dependencies}")
# split into list, one item per source file
string(REPLACE "\n" ";" dependencies "${dependencies}")

# Get a list of all includes from dep file
foreach(source IN LISTS SOURCES)
    set(entries "${dependencies}")

	# Filter by source file
	clang_tools_regex_escape_pattern(source OUT pattern)
    list(FILTER entries INCLUDE REGEX "^${pattern}:\t")
	# Get headers only
    list(TRANSFORM entries REPLACE "^${pattern}:\t" "")

	# Add tab-separated list of includes
    if(entries)
        list(APPEND unseen_includes "${entries}")
    endif()
endforeach()

# Build a single string
list(JOIN unseen_includes "\t" unseen_includes)

# Convert to list
string(REPLACE "\t" ";" unseen_includes "${unseen_includes}")
list(FILTER unseen_includes EXCLUDE REGEX "^ *$")
list(TRANSFORM unseen_includes STRIP)

message("QQQ\n${dependencies}\nPPP")
message("AAA ${unseen_includes}")
if(unseen_includes)
    list(LENGTH unseen_includes count)
    foreach(index RANGE 1 ${count})
        list(POP_FRONT unseen_includes include)
        cmake_path(ABSOLUTE_PATH include NORMALIZE)
        string(REPLACE ";" "\\;" include "${include}")
        list(APPEND unseen_includes "${include}")
    endforeach()
endif()
message("BBB ${unseen_includes}")

# Remove known includes
list(REMOVE_ITEM unseen_includes ${INCLUDES})

# Restrict to unseen_includes in or below source directory
clang_tools_regex_escape_pattern(SOURCE_DIR OUT pattern)
list(FILTER unseen_includes INCLUDE REGEX "^${pattern}/")
list(REMOVE_DUPLICATES unseen_includes)

# Get first source file for each auxiliary include
foreach(include IN LISTS AUX_INCLUDES)
    set(candidates "${dependencies}")

	clang_tools_regex_escape_pattern(include OUT pattern)
    list(FILTER candidates INCLUDE REGEX "\t+${pattern}(\t|$)")
    list(TRANSFORM candidates REPLACE "^([^\t]+):\t.*" "\\1")
	list(SORT candidates CASE INSENSITIVE)

    unset(file)
    foreach(candidate IN LISTS candidates)
        if(candidate IN_LIST SOURCES)
            set(file "${candidate}")
            break()
        endif()
    endforeach()
    if(NOT file)
        message(FATAL_ERROR "Include is never used: ${include}")
    endif()
    string(APPEND mapping "${file}\t${include}\n")

    list(REMOVE_ITEM unseen_includes "${include}")
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
    message(FATAL_ERROR "Target ${TARGET} has undeclared includes: ${unseen_includes}")
endif()

# Write .auxi file for each source
foreach(source output IN ZIP_LISTS SOURCES OUTPUTS)
    set(entries "${mapping}")

	clang_tools_regex_escape_pattern(source OUT pattern)
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
