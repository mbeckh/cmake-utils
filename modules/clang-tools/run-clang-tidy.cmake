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
#        [-D FILES=<file>;... | -D ninja_EXE=<file>]
#        -D OUTPUT=<file>
#        -P run-clang-tidy.cmake
#
cmake_minimum_required(VERSION 3.25 FATAL_ERROR)

foreach(arg clang-tidy_EXE COMPILE_COMMANDS_PATH OUTPUT)
    if(NOT ${arg})
        message(FATAL_ERROR "${arg} is missing or empty")
    endif()
endforeach()
if(NOT FILES AND NOT ninja_EXE)
    message(FATAL_ERROR "Both FILE and ninja_EXE are missing or empty")
endif()

if(FILES)
    execute_process(COMMAND "${clang-tidy_EXE}"
                            "${FILES}"
                            "@${COMPILE_COMMANDS_PATH}clang-tidy-checks.arg"
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

    unset(files)
    unset(results)

    if(last GREATER -1)
        foreach(i RANGE ${last})
            string(JSON file GET "${compile_commands}" ${i} "file")
            # Do not run clang-tidy for precompiled headers to prevent duplicate processing.
            # Includes are supposed to be included by source files (include what you use).
            if(NOT file MATCHES "[/\\\\]cmake_pch.c(xx)$")
                list(APPEND files "${file}")
                list(APPEND results "${file}.tidy")
            endif()
        endforeach()
    endif()

    if (files)
        list(SORT files)
        list(SORT results)

        # Write ninja file only if something relevant has changed
        if(NOT (EXISTS "${COMPILE_COMMANDS_PATH}/clang-tidy.ninja"
                AND "${COMPILE_COMMANDS_PATH}/clang-tidy.ninja" IS_NEWER_THAN "${compile_commands}"
                AND "${COMPILE_COMMANDS_PATH}/clang-tidy.ninja" IS_NEWER_THAN "${CMAKE_CURRENT_LIST_FILE}"))

            unset(ninjafile)
            string(CONFIGURE [[
rule tidy
  command = cmd.exe /C "cd /D "@COMPILE_COMMANDS_PATH@" && "@clang-tidy_EXE@" "$file" "@@COMPILE_COMMANDS_PATH@clang-tidy-checks.arg" -p "@COMPILE_COMMANDS_PATH@" --extra-arg=/clang:-MD "--extra-arg=/clang:-MF$out.d" "--extra-arg=/clang:-MT$out" "--header-filter=.*" > "$out" 2>&1 & copy /y "$out.d" "$out.d2""
  depfile = $out.d2
  deps = gcc
  restat = 1
]] rule @ONLY)
            list(APPEND ninjafile
                "ninja_required_version = 1.5"
                "builddir = ${COMPILE_COMMANDS_PATH}"
                "${rule}")

            foreach(file IN LISTS files)
                # escape colons and spaces for build rule
                string(REGEX REPLACE "([: $])" "$\\1" file4ninja "${file}")
                string(REGEX REPLACE "([: $])" "$\\1" path4ninja "${COMPILE_COMMANDS_PATH}")

                cmake_path(GET file FILENAME filename)

                string(CONFIGURE [[
build @file4ninja@.tidy: tidy @file4ninja@ @path4ninja@clang-tidy-checks.arg
  file = @file@
  description = clang-tidy: Analyzing @filename@
]] build @ONLY)
                list(APPEND ninjafile "${build}")
            endforeach()

            list(JOIN ninjafile "\n" ninjafile)
            file(WRITE "${COMPILE_COMMANDS_PATH}/clang-tidy.ninja" "${ninjafile}")
        endif()

        execute_process(COMMAND "${ninja_EXE}"
                                -f clang-tidy.ninja
                        WORKING_DIRECTORY "${COMPILE_COMMANDS_PATH}"
                        RESULT_VARIABLE result
                        ERROR_VARIABLE error
                        OUTPUT_VARIABLE output
                        COMMAND_ECHO NONE)

        if(NOT result EQUAL 0)
            message(FATAL_ERROR "Error ${result}:\n${error}${output}")
        endif()

        execute_process(COMMAND "${CMAKE_COMMAND}"
                                -D "TOOL=clang-tidy"
                                -D "OUTPUT=${OUTPUT}"
                                -D "FILES=${results}"
                                -P "${CMAKE_CURRENT_LIST_DIR}/cat.cmake"
                        WORKING_DIRECTORY "${COMPILE_COMMANDS_PATH}"
                        RESULT_VARIABLE result
                        ERROR_VARIABLE error
                        OUTPUT_VARIABLE output
                        COMMAND_ECHO NONE)
    else()
        file(WRITE "${OUTPUT}" "")
    endif()
endif()

if((FILES OR files) AND NOT result EQUAL 0)
    message(FATAL_ERROR "Error ${result}:\n${error}${output}")
endif()


if(FILES)
    file(WRITE "${OUTPUT}" "${output}")
else()
    # Create master depfile
    cmake_path(NATIVE_PATH OUTPUT NORMALIZE OUTPUT)
    set(alldeps "${OUTPUT}: ")
    foreach(file IN LISTS results)
        file(STRINGS "${file}.d" depfile REGEX "^ ")
        list(APPEND alldeps "${depfile} ")
    endforeach()
    list(REMOVE_DUPLICATES alldeps)
    list(JOIN alldeps "\n" alldeps)
    string(REPLACE "\n" "\\\n" alldeps "${alldeps}")
    file(WRITE "${COMPILE_COMMANDS_PATH}/clang-tidy.d" "${alldeps}\n")
endif()
