# Copyright 2023 Michael Beckh
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
# Run clang-tidy.
# Usage: cmake
#        -D clang-tidy_EXE=<file>
#        -D COMPILE_COMMANDS_PATH=<path>
#        [-D FILES=<file>;... | -D INTERMEDIATE_FILE=<file>]
#        -D OUTPUT=<file>
#        -P run-clang-tidy.cmake
#
cmake_minimum_required(VERSION 3.25 FATAL_ERROR)

foreach(arg clang-tidy_EXE COMPILE_COMMANDS_PATH OUTPUT)
    if(NOT ${arg})
        message(FATAL_ERROR "${arg} is missing or empty")
    endif()
endforeach()
if(NOT FILES AND NOT INTERMEDIATE_FILE)
    message(FATAL_ERROR "Both FILE and INTERMEDIATE_FILE are missing or empty")
endif()

file(SIZE "${COMPILE_COMMANDS_PATH}clang-tidy-checks.arg" checks_size)
if(checks_size)
    set(checks "@${COMPILE_COMMANDS_PATH}clang-tidy-checks.arg")
endif()

if(FILES)
    execute_process(COMMAND "${clang-tidy_EXE}"
                            "${FILES}"
                            ${checks}
                            -p "${COMPILE_COMMANDS_PATH}"
                            "--extra-arg=/clang:-MD"
                            "--extra-arg=/clang:-MF${OUTPUT}.d"
                            "--extra-arg=/clang:-MT${OUTPUT}"
                            "--header-filter=.*"
                    RESULT_VARIABLE result
                    ERROR_VARIABLE error
                    OUTPUT_VARIABLE output
                    COMMAND_ECHO NONE)
else()
    file(READ "${COMPILE_COMMANDS_PATH}compile_commands.json" compile_commands)
    string(JSON last LENGTH "${compile_commands}")
    math(EXPR last "${last} - 1")

    if(last GREATER -1)
        foreach(i RANGE ${last})
            string(JSON file GET "${compile_commands}" ${i} "file")
            # Do not run clang-tidy for precompiled headers to prevent duplicate processing.
            # Includes are supposed to be included by source files (include what you use).
            if(NOT file MATCHES "[/\\\\]cmake_pch.c(xx)$")
                list(APPEND args "${file}")
            endif()
        endforeach()
    endif()

    if(NOT files)
        # no files, empty output
        file(WRITE "${OUTPUT}" "")
        file(WRITE "${DEPFILE}" "${OUTPUT}:")
        return()
    endif()

    list(JOIN args "\n" args)
    file(WRITE "${INTERMEDIATE_FILE}.args" "${args}")

    execute_process(COMMAND "${clang-tidy_EXE}"
                            "@${INTERMEDIATE_FILE}.args"
                            ${checks}
                            -p "${COMPILE_COMMANDS_PATH}"
                            "--extra-arg=/clang:-MD"
                            "--extra-arg=/clang:-MF${INTERMEDIATE_FILE}.d"
                            "--extra-arg=/clang:-MT${OUTPUT}"
                            "--header-filter=.*"
                    RESULT_VARIABLE result
                    ERROR_VARIABLE error
                    OUTPUT_VARIABLE output
                    COMMAND_ECHO NONE)
endif()

if(NOT result EQUAL 0)
    message(FATAL_ERROR "Error ${result}:\n${error}${output}")
endif()

if(FILES)
    file(WRITE "${OUTPUT}" "${output}")
else()
    file(WRITE "${INTERMEDIATE_FILE}" "${output}")
endif()
