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
# Common tool chain for Visual Studio 2019 with vcpkg.
#
include_guard(GLOBAL)

message(STATUS "Applying vcpkg settings: ${CMAKE_CURRENT_LIST_DIR}")
include("${CMAKE_CURRENT_LIST_DIR}/_shared.cmake")

# Remaining settings are MSVC only
if(NOT MSVC)
    return()
endif()

#
# Compiler options
#

# Debug information
add_compile_options("$<$<COMPILE_LANGUAGE:C,CXX>:/Z7>"
                    # cannot combine into one argument because CMake gets trailing backslash wrong
                    "$<$<COMPILE_LANGUAGE:C,CXX>:/d1trimfile:$<SHELL_PATH:$<TARGET_PROPERTY:SOURCE_DIR>/>>"
                    "$<$<COMPILE_LANGUAGE:C,CXX>:/d1trimfile:$<SHELL_PATH:$<TARGET_PROPERTY:BINARY_DIR>/>>")

#
# Linker options
#

# Debug information
add_link_options(/DEBUG:FULL)
