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
# Remove MSVC-only flags from compile_commands.json which are not understood by clang's MSVC driver.
# Usage: cmake -P compile_commands.cmake
#
cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

file(READ "compile_commands.json" compile_commands)
string(JSON count LENGTH "${compile_commands}")
math(EXPR count "${count} - 1")
set(changed NO)

foreach(i RANGE ${count})
    math(EXPR index "${count} - ${i}")
    string(JSON command GET "${compile_commands}" ${index} "command")

    if(NOT command MATCHES " [/-]Fo([^/\\\\]+[/\\\\])*CMakeFiles[/\\\\]${TARGET}\\.dir[/\\\\]")
        # entry belongs to a different target 
        string(JSON compile_commands REMOVE "${compile_commands}" ${index})
        continue()
    endif()
    string(REGEX REPLACE "(^| )[/-]external:I " " /clang:-isystem" command "${command}")
    separate_arguments(command NATIVE_COMMAND "${command}")
    list(FILTER command EXCLUDE REGEX "^[/-](Y[cu]|FI|Fp|d1trimfile:).*$")
    list(FILTER command EXCLUDE REGEX "^[/-](experimental:external|external:W[0-4])$")
    list(TRANSFORM command REPLACE [[\\]] [[\\\\]])
    list(JOIN command " " command)
    string(JSON compile_commands SET "${compile_commands}" ${index} "command" "\"${command}\"")
endforeach()

file(WRITE ".clang-tools/${TARGET}/compile_commands.json" "${compile_commands}")
