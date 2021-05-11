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
# Helper functions for debugging CMake scripts.
#

include_guard(GLOBAL)

#
# dump_variables()
#
# Dump all CMake and environment variables for debugging.
# Run CMake with --log-level=TRACE to see the output.
#
function(dump_variables)
    message(TRACE "--  --  --  --  --  --  --  --  --  --  --")

    message(TRACE "Variables:")
    get_cmake_property(names VARIABLES)
    list(SORT names CASE INSENSITIVE)

    list(APPEND CMAKE_MESSAGE_INDENT "-- ")
    foreach (name IN LISTS names)
        message(TRACE "${name}=${${name}}")
    endforeach()
    list(POP_BACK CMAKE_MESSAGE_INDENT)

    message(TRACE "Environment:")
    execute_process(COMMAND "${CMAKE_COMMAND}" -E environment OUTPUT_VARIABLE env)
    # Replace list separator ; with <escape>;
    string(REPLACE ";" "\\\\\\;" env "${env}")
    # Replace line separator with list separator
    string(REGEX REPLACE "\r?\n" ";" env "${env}")
    list(REMOVE_ITEM env "")
    list(SORT env CASE INSENSITIVE)

    list(APPEND CMAKE_MESSAGE_INDENT "-- ")
    foreach(line IN LISTS env)
        message(TRACE "${line}")
    endforeach()
    list(POP_BACK CMAKE_MESSAGE_INDENT)

    message(TRACE "--  --  --  --  --  --  --  --  --  --  --")
endfunction()
