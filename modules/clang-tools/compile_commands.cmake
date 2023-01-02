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
# Remove MSVC-only flags from compile_commands.json which are not understood by clang's MSVC driver.
# Usage: cmake
#        -D TARGET=<name>
#        -D CONFIG_SUBDIR=<if_multiconfig_name_and_slash_else_empty>
#        -D clang_EXE=<path>
#        -D MSVC_VERSION=<version>
#        -P compile_commands.cmake
#
cmake_minimum_required(VERSION 3.25 FATAL_ERROR)

foreach(arg TARGET clang_EXE clang_EXE MSVC_VERSION)
    if(NOT ${arg})
        message(FATAL_ERROR "${arg} is missing or empty")
    endif()
endforeach()

file(READ "compile_commands.json" compile_commands)
string(JSON count LENGTH "${compile_commands}")
math(EXPR count "${count} - 1")
set(changed NO)

if(CONFIG_SUBDIR)
    string(REGEX REPLACE "/$" "[/\\\\]" config_subdir_pattern "${CONFIG_SUBDIR}")
endif()

# compile_commands.json uses native paths
cmake_path(NATIVE_PATH clang_EXE NORMALIZE clang_EXE)

foreach(i RANGE ${count})
    math(EXPR index "${count} - ${i}")
    string(JSON command GET "${compile_commands}" ${index} "command")

    if(NOT command MATCHES " [/-]Fo([^/\\\\]+[/\\\\])*CMakeFiles[/\\\\]${TARGET}\\.dir[/\\\\]${config_subdir_pattern}")
        # entry belongs to a different target or config
        string(JSON compile_commands REMOVE "${compile_commands}" ${index})
        continue()
    endif()

    string(REGEX REPLACE "(^| )[/-]external:I ?" " /clang:-isystem" command "${command}")
    separate_arguments(command NATIVE_COMMAND "${command}")
    list(FILTER command EXCLUDE REGEX "^[/-](Y[cu]|FI|Fp|d1trimfile:).*$")
    list(FILTER command EXCLUDE REGEX "^[/-](experimental:external|external:W[0-4])$")
    list(FILTER command EXCLUDE REGEX "^[/-](GL|MP|Z[Ii7]|Ob3|JMC)$")
    list(POP_FRONT command)
    list(PREPEND command "\"${clang_EXE}\"" "--driver-mode=cl")
    list(INSERT command 2 "/clang:-fmsc-version=${MSVC_VERSION}"
                          "-D__clang_analyzer__"
                          "-D_CRT_USE_BUILTIN_OFFSETOF")

    list(LENGTH command arg_count)
    foreach(j RANGE ${arg_count})
        list(GET command ${j} arg)
        if(arg MATCHES "^[/-]c$")
            math(EXPR file_index "${j} + 1")
            list(GET command "${file_index}" file)

            #cmake_path(IS_PREFIX SOURCE_DIR "${file}" NORMALIZE is_prefix)
            #if(is_prefix)
            #    # PCH check is only use for a file in binary path and this check does not use DEPFILE
            #    cmake_path(RELATIVE_PATH file BASE_DIRECTORY "${SOURCE_DIR}")
            #    list(INSERT command ${j} "/clang:-MD" "/clang:-MF.clang-tools/${TARGET}-${TOOL}/${CONFIG_DIR}${file}.txt.d" "/clang:-MT.clang-tools/${TARGET}-${TOOL}/${CONFIG_DIR}${file}.txt")
            #endif()
            break()
        endif()
    endforeach()

    list(TRANSFORM command REPLACE [[\\]] [[\\\\]])
    list(TRANSFORM command REPLACE [["]] [[\\\\\\"]])
    list(JOIN command " " command)
    string(JSON compile_commands SET "${compile_commands}" ${index} "command" "\"${command}\"")
endforeach()

file(WRITE ".clang-tools/${TARGET}/${CONFIG_SUBDIR}compile_commands.json" "${compile_commands}")
