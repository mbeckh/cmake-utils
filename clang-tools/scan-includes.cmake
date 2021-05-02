#
# Detect all system includes for a source file or precompiled header.
# Usage: cmake
#        -D TARGET=<name>
#        -D SOURCE_DIR=<path>
#        -D BINARY_DIR=<path>
#        [ -D FILES=<file>;... | -D PCH=<language> ]
#        -D OUTPUT=<file>
#        -P scan-includes.cmake
#
# MIT License, Copyright (c) 2021 Michael Beckh, see LICENSE
#
cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

if(NOT FILES AND NOT PCH)
    message(FATAL_ERROR "No input files or PCH")
endif()

file(READ "compile_commands.json" compile_commands)
string(JSON count LENGTH "${compile_commands}")
math(EXPR count "${count} - 1")

set(system_include_path $ENV{INCLUDE})

foreach(i RANGE ${count})
    string(JSON file GET "${compile_commands}" ${i} "file")

    cmake_path(CONVERT "${file}" TO_CMAKE_PATH_LIST file)
    if(FILES)
        list(FIND FILES "${file}" index)
        if(index EQUAL -1)
            continue()
        endif()
        list(REMOVE_AT FILES ${index})
    elseif(PCH)
        if(NOT file MATCHES "^${BINARY_DIR}/CMakeFiles/${TARGET}.dir/cmake_pch.c(.+)$")
            continue()
        endif()
    endif()

    string(JSON command GET "${compile_commands}" ${i} "command")
    string(JSON directory GET "${compile_commands}" ${i} "directory")

    separate_arguments(command NATIVE_COMMAND "${command}")
    list(FILTER command EXCLUDE REGEX "^[/-]((Y[cu]|F[dop]).*)|c$")
    if(NOT PCH)
        # do not remove forced include for PCH
        list(FILTER command EXCLUDE REGEX "^[/-]FI.*$")
    endif()
    list(INSERT command 1 /EP /showIncludes)

    execute_process(COMMAND ${command}
                    WORKING_DIRECTORY "${directory}"
                    RESULT_VARIABLE result
                    ERROR_VARIABLE results
                    OUTPUT_QUIET
                    COMMAND_ECHO NONE)
    if(result)
        message(FATAL_ERROR "Error ${result}:\n${results}")
    endif()

    string(REPLACE ";" "\\;" results "${results}")
    string(REGEX REPLACE "[\r\n]+" ";" results "${results}")
    list(FILTER results INCLUDE REGEX "^Note: including file:")
    list(TRANSFORM results REPLACE "^Note: including file: " "")

    set(ignore "-")
    unset(includes)
    while(results)
        list(POP_FRONT results item)
        string(STRIP "${item}" file)
        cmake_path(CONVERT "${file}" TO_CMAKE_PATH_LIST file NORMALIZE)
        if(NOT ignore STREQUAL "-" AND item MATCHES "^${ignore} ")
            continue()
        endif()
        cmake_path(IS_PREFIX SOURCE_DIR "${file}" NORMALIZE prefix)
        if(NOT prefix AND PCH)
            cmake_path(IS_PREFIX BINARY_DIR "${file}" NORMALIZE prefix)
        endif()
        if(NOT prefix)
            foreach(system_include IN LISTS system_include_path)
                cmake_path(CONVERT "${system_include}" TO_CMAKE_PATH_LIST system_include)
                cmake_path(IS_PREFIX system_include "${file}" NORMALIZE prefix)
                if(prefix)
                    cmake_path(RELATIVE_PATH file BASE_DIRECTORY "${system_include}")
                    break()
                endif()
            endforeach()
            string(REGEX MATCH "^ +" ignore "${item}")
            string(REPLACE ";" "\\;" file "${file}")
            list(APPEND includes "${file}")
        else()
            set(ignore "-")
        endif()
    endwhile()

    if(NOT FILES AND NOT PCH)
        break()
    endif()
endforeach()

list(SORT includes CASE INSENSITIVE)
list(JOIN includes "\n" includes)

file(WRITE "${OUTPUT}" "${includes}")
