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
# Concatenate files to stderr or file.
# Usage: cmake
#        [ -D COLOR=<color> | -D OUTPUT=<file> ]
#        -D FILES=<file>;...
#        -P cat.cmake
# Note: cmake -E cat Does not work: Stops on empty file as of CMake 3.20.0.
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
