#
# Output result files to stderr using shell formatting.
# Usage: cmake
#        -D TOOL=<name>
#        -D SOURCE_DIR=<path>
#        .D FILES=<file>;...
#        -P cat-result.cmake
#
# MIT License, Copyright (c) 2021 Michael Beckh, see LICENSE
#
cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

if(NOT FILES)
    message(FATAL_ERROR "No input files")
endif()

#https://en.wikipedia.org/wiki/ANSI_escape_code
string(ASCII 27 esc)
set(fmt_off "${esc}[m")
set(fmt_ok "${esc}[97m")
set(fmt_error "${esc}[93m")
set(fmt_text "${esc}[96m")
set(fmt_rule "${esc}[95m")

foreach(input IN LISTS FILES)
    file(STRINGS "${input}" content)

    if(TOOL STREQUAL iwyu OR TOOL STREQUAL pch)
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
            else()
                message("${line}")
            endif()
        endforeach()
    elseif(TOOL STREQUAL clang-tidy)
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
