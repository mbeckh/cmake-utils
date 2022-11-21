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
# Main include for cmake-utils.
# Use cmake-utils by including this file in a project using either include(), CMAKE_PROJECT_INCLUDE or toolchain.cmake.
#

include_guard(GLOBAL)
message(STATUS "Including cmake-utils: ${CMAKE_CURRENT_LIST_DIR}")

#
# cmake_utils_for_each_target(<command> ARGS <args> ... [DIRECTORY <path>])
#
# Call cmd(<target> <args> ... ) for each known target in <path> and its subdirectories.
# If DIRECTORY is not specified, CMAKE_SOURCE_DIR is used.
#
function(cmake_utils_for_each_target _cu_fet_command #[[ ARGS <args> ... DIRECTORY <path> OUT <var> ...]])
    # Use prefix _cu_fet_ for all local variables to avoid name conflicts with ARGS and OUT
    cmake_parse_arguments(PARSE_ARGV 1 _cu_fet_arg "" "DIRECTORY" "ARGS;OUT")
    if(NOT _cu_fet_arg_DIRECTORY)
        set(_cu_fet_arg_DIRECTORY "${CMAKE_SOURCE_DIR}")
    endif()

    unset(_cu_fet_directories)
    string(REPLACE ";" "\\;" _cu_fet_arg_DIRECTORY "${_cu_fet_arg_DIRECTORY}")
    list(APPEND _cu_fet_directories "${_cu_fet_arg_DIRECTORY}")

    while(_cu_fet_directories)
        list(POP_FRONT _cu_fet_directories _cu_fet_directory)
        get_directory_property(_cu_fet_targets DIRECTORY "${_cu_fet_directory}" BUILDSYSTEM_TARGETS)
        foreach(_cu_fet_target IN LISTS _cu_fet_targets)
            cmake_language(CALL "${_cu_fet_command}" "${_cu_fet_target}" ${_cu_fet_arg_ARGS})
        endforeach()
        get_directory_property(_cu_fet_subdirectories DIRECTORY "${_cu_fet_directory}" SUBDIRECTORIES)
        if(_cu_fet_subdirectories)
            list(APPEND _cu_fet_directories "${_cu_fet_subdirectories}")
        endif()
    endwhile()
    foreach(_cu_fet_out IN LISTS _cu_fet_arg_OUT)
        set("${_cu_fet_out}" "${${_cu_fet_out}}" PARENT_SCOPE)
    endforeach()
endfunction()

function(z_cmake_utils_add_to_module_path)
    list(FIND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}" index)
    if(index EQUAL -1)
        list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}")
        set(CMAKE_MODULE_PATH "${CMAKE_MODULE_PATH}" CACHE STRING "" FORCE)
    endif()
endfunction()

z_cmake_utils_add_to_module_path()

# Inject common build settings
include("${CMAKE_CURRENT_LIST_DIR}/settings/common.cmake")

# Default configuration for vcpkg
set(VCPKG_FEATURE_FLAGS "versions,registries,binarycaching" CACHE PATH "Default features for vcpkg")
set(VCPKG_TARGET_TRIPLET "x64-windows-static" CACHE STRING "Default configuration for vcpkg")

# Hooks to include additional user settings or overrides
include("${CMAKE_CURRENT_LIST_DIR}/../UserSettings.cmake" OPTIONAL NO_POLICY_SCOPE)
include("${CMAKE_SOURCE_DIR}/cmake/UserSettings.cmake" OPTIONAL NO_POLICY_SCOPE)

# Fire up vcpkg if required
if(EXISTS "${CMAKE_SOURCE_DIR}/vcpkg.json")
    find_package(vcpkg MODULE REQUIRED)
endif()

# Make check utils available
if(NOT DEFINED CMU_CLANG_TOOLS OR CMU_CLANG_TOOLS)
    find_package(ClangTools)
    find_package(clang-tidy)
    find_package(include-what-you-use)
endif()

# Install checks
if(COMMAND "clang_tidy")
    clang_tidy(ALL)
endif()
if(COMMAND "include_what_you_use")
	include_what_you_use(ALL)
endif()
if(COMMAND "check_pch")
	check_pch(ALL)
endif()
