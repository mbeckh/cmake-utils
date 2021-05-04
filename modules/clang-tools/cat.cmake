#
# Concatenate files to stderr or file.
# Usage: cmake
#        [ -D COLOR=<color> | -D OUTPUT=<file> ]
#        -D FILES=<file>;...
#        -P cat.cmake
# Note: cmake -E cat Does not work: Stops on empty file as of CMake 3.20.0.
#
# MIT License, Copyright (c) 2021 Michael Beckh, see LICENSE
#
cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

if(NOT FILES)
    message(FATAL_ERROR "No input files")
endif()

if(OUTPUT)
    if(COLOR)
        message(FATAL_ERROR "Cannot use --output and --color at the same time")
    endif()
    file(REMOVE "${OUTPUT}")
endif()

if(COLOR STREQUAL cyan)
    string(ASCII 27 esc)
    message("${esc}[96m")
endif()

foreach(file IN LISTS FILES)
    file(READ "${file}" contents)
    if(OUTPUT)
        file(APPEND "${OUTPUT}" "${contents}")
    else()
        message("${contents}")
    endif()
endforeach()

if(COLOR)
    message("${esc}[m")
endif()
