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
# Common tool chain for Visual Studio 2019 with vcpkg.
#
include_guard(GLOBAL)

message(STATUS "Applying vcpkg settings: ${CMAKE_CURRENT_LIST_DIR}")
include("${CMAKE_CURRENT_LIST_DIR}/_shared.cmake")

# Remaining settings are MSVC only
if(NOT MSVC)
    return()
endif()

block()
    #
    # Compiler options
    #

    # Debug information
    set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT "Embedded" CACHE STRING "")
    cmake_policy(GET CMP0141 msvc_debug_information_format)
    if(NOT msvc_debug_information_format STREQUAL NEW)
        add_compile_options("$<$<COMPILE_LANGUAGE:C,CXX>:/Z7>")
    endif()

    add_compile_options(# cannot combine into one argument because CMake gets trailing backslash wrong
                        "$<$<COMPILE_LANGUAGE:C,CXX>:/d1trimfile:$<SHELL_PATH:$<TARGET_PROPERTY:SOURCE_DIR>/>>"
                        "$<$<COMPILE_LANGUAGE:C,CXX>:/d1trimfile:$<SHELL_PATH:$<TARGET_PROPERTY:BINARY_DIR>/>>")

    #
    # Linker options
    #

    # Debug information (always added, does NOT evaluate CMU_DISABLE_DEBUG_INFORMATION because result might be cached and re-used by different builds)
    add_link_options(/DEBUG:FULL)
endblock()
