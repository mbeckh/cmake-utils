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
# Load and configure vcpkg.
#

if(vcpkg_FOUND)
    return()
endif()

# vcpkg revision
set(vcpkg_INSTALL_REVISION "395cb682bd8f9cc65228f48e40390f5241373659" CACHE STRING "Revision of vcpkg if not using system binaries")

#
# Check and configure required settings
#
if(NOT BUILD_ROOT)
    if(DEFINED ENV{BUILD_ROOT})
        # allow unified access to value for cache and environment variable
        set(BUILD_ROOT "$ENV{BUILD_ROOT}")
    else()
        message(FATAL_ERROR "Build requires setting BUILD_ROOT to a valid output directory")
	endif()
endif()

cmake_path(ABSOLUTE_PATH BUILD_ROOT NORMALIZE)
set(BUILD_ROOT "${BUILD_ROOT}" CACHE PATH "Root output directory for all projects" FORCE)

include(FindPackageHandleStandardArgs)

#
# Load or update vcpkg
#

function(z_vcpkg_get_version)
    execute_process(COMMAND "${vcpkg_EXE}" version OUTPUT_VARIABLE out)
    if(out MATCHES "Vcpkg package management program version [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-([0-9a-f]+)")
        set(vcpkg_REVISION "${CMAKE_MATCH_1}" PARENT_SCOPE)
    endif()
endfunction()

function(z_vcpkg_get_revision)
    file(READ "${vcpkg_ROOT}/.git/HEAD" revision)
    string(STRIP "${revision}" revision)
    set(vcpkg_REVISION "${revision}" PARENT_SCOPE)
endfunction()

if(NOT DEFINED vcpkg_ROOT AND DEFINED ENV{vcpkg_ROOT})
    set(vcpkg_ROOT "$ENV{vcpkg_ROOT}")
endif()

if(DEFINED vcpkg_ROOT)
    # Use system vcpkg
    find_program(vcpkg_EXE vcpkg PATHS "${vcpkg_ROOT}" NO_DEFAULT_PATH)
    if(vcpkg_EXE)
        z_vcpkg_get_version()
    elseif(EXISTS "${vcpkg_ROOT}/.git/HEAD")
        # Fallback to revision because vcpkg can bootstrap its own executable
        z_vcpkg_get_revision()
        set(vcpkg_EXE "${vcpkg_ROOT}/vcpkg${CMAKE_EXECUTABLE_SUFFIX}")
    endif()
    find_package_handle_standard_args(vcpkg REQUIRED_VARS vcpkg_ROOT vcpkg_EXE vcpkg_REVISION VERSION_VAR vcpkg_REVISION)
else()
    set(vcpkg_ROOT "${BUILD_ROOT}/vcpkg")
    if(EXISTS "${vcpkg_ROOT}/.git/HEAD")
        z_vcpkg_get_revision()
        if(vcpkg_INSTALL_REVISION STREQUAL vcpkg_REVISION)
            find_package_handle_standard_args(vcpkg REQUIRED_VARS vcpkg_ROOT VERSION_VAR vcpkg_REVISION)
        else()
            find_package(Git REQUIRED)
            if (Git_FOUND)
                execute_process(COMMAND "${GIT_EXECUTABLE}" "fetch" WORKING_DIRECTORY "${vcpkg_ROOT}")
                execute_process(COMMAND "${GIT_EXECUTABLE}" "checkout" "${vcpkg_INSTALL_REVISION}" WORKING_DIRECTORY "${vcpkg_ROOT}")
                z_vcpkg_get_revision()
            endif()
            find_package_handle_standard_args(vcpkg REQUIRED_VARS vcpkg_ROOT Git_FOUND VERSION_VAR vcpkg_REVISION)
        endif()
    else()
        find_package(Git REQUIRED)
        if (Git_FOUND)
            execute_process(COMMAND "${GIT_EXECUTABLE}" "clone" "--no-checkout" "https://github.com/microsoft/vcpkg.git" "${vcpkg_ROOT}")
            execute_process(COMMAND "${GIT_EXECUTABLE}" "checkout" "--quiet" "${vcpkg_INSTALL_REVISION}" WORKING_DIRECTORY "${vcpkg_ROOT}")
            z_vcpkg_get_revision()
        endif()
        find_package_handle_standard_args(vcpkg REQUIRED_VARS vcpkg_ROOT Git_FOUND VERSION_VAR vcpkg_REVISION)
    endif()
endif()


#
# Configure vcpkg
#

# Some variables are not forwarded by vcpkg.cmake and MUST be set as an environment variables
if(VCPKG_DOWNLOADS)
    set(ENV{VCPKG_DOWNLOADS} "${VCPKG_DOWNLOADS}")
else()
    set(ENV{VCPKG_DOWNLOADS} "${BUILD_ROOT}/vcpkg-downloads")
endif()
if(VCPKG_BINARY_SOURCES)
    set(ENV{VCPKG_BINARY_SOURCES} "${VCPKG_BINARY_SOURCES}")
else()
    set(ENV{VCPKG_BINARY_SOURCES} "clear;files,${BUILD_ROOT}/vcpkg-binaries,readwrite")
endif()
if(VCPKG_DISABLE_METRICS)
    set(ENV{VCPKG_DISABLE_METRICS} "${VCPKG_DISABLE_METRICS}")
endif()

set(VCPKG_OVERLAY_TRIPLETS "${CMAKE_CURRENT_LIST_DIR}/triplets" CACHE PATH "Additional triplets for vcpkg")

function(z_vcpkg_set_install_options)
    set(path "${CMAKE_BINARY_DIR}")
    while(TRUE)
        cmake_path(GET path PARENT_PATH parent)
        if(parent STREQUAL BUILD_ROOT)
            cmake_path(GET path FILENAME project)
            set(project_root "${BUILD_ROOT}/${project}")
            break()
        endif()
        cmake_path(HAS_FILENAME path has_filename)
        if(has_filename)
            set(path "${parent}")
        else()
            set(project_root "${CMAKE_BINARY_DIR}")
            break()
        endif()
    endwhile()

    set(VCPKG_INSTALL_OPTIONS "--x-buildtrees-root=${project_root}/vcpkg-buildtrees;--x-packages-root=${project_root}/vcpkg-packages" CACHE STRING "Additional options for vcpkg")
endfunction()
z_vcpkg_set_install_options()

# vcpkg does not yet allow setting the packages directory to a custom folder
set(ENV{LOCALAPPDATA} "${BUILD_ROOT}/vcpkg-local-app-data")

set(VCPKG_OVERRIDE_FIND_PACKAGE_NAME "vcpkg_find_package")

#
# configure_local_vcpkg_package(<target>)
#
# Change config settings for vcpkg packages included from a local path.
#
function(z_vcpkg_configure_local_target target)
    get_property(includes TARGET "${target}" PROPERTY INTERFACE_INCLUDE_DIRECTORIES)
    set_property(TARGET "${target}" APPEND PROPERTY INTERFACE_SYSTEM_INCLUDE_DIRECTORIES ${includes})
endfunction()

function(z_vcpkg_configure_local_package name)
    get_property(local GLOBAL PROPERTY VCPKG_LOCAL_DEPENDENCY_NAMES)
    if(NOT name IN_LIST local)
        set_property(GLOBAL APPEND PROPERTY VCPKG_LOCAL_DEPENDENCY_NAMES "${name}")
        add_subdirectory("${LOCAL_${name}_ROOT}" "${CMAKE_BINARY_DIR}/_local/${name}" EXCLUDE_FROM_ALL)
        cmake_utils_for_each_target(z_vcpkg_configure_local_target DIRECTORY "${LOCAL_${name}_ROOT}")
    endif()
endfunction()

if(NOT COMMAND _find_package)
    # Replacement for CMake's find_package.
    # MUST be a macro because vcpkg exports variables to parent scope.
    macro(find_package name)
        if(DEFINED LOCAL_${name}_ROOT)
            if(NOT IS_DIRECTORY "${LOCAL_${name}_ROOT}")
                find_package_handle_standard_args(${name} REQUIRED_VARS ${name}_FOUND REASON_FAILURE_MESSAGE "LOCAL_${name}_ROOT specified, but not present at ${LOCAL_${name}_ROOT}")
            elseif(NOT EXISTS "${LOCAL_${name}_ROOT}/CMakeLists.txt")
                find_package_handle_standard_args(${name} REQUIRED_VARS ${name}_FOUND REASON_FAILURE_MESSAGE "LOCAL_${name}_ROOT found at ${LOCAL_${name}_ROOT} but no CMakeListst.txt")
            else()
                # Force message to show every time for local overrides
                string(TIMESTAMP now UTC)
                find_package_handle_standard_args(${name} DEFAULT_MSG LOCAL_${name}_ROOT now)
                unset(now)
                z_vcpkg_configure_local_package("${name}")
            endif()
        elseif(COMMAND vcpkg_find_package)
            vcpkg_find_package(${ARGV})
        else()
            _find_package(${ARGV})
        endif()
    endmacro()
endif()

if(vcpkg_FOUND)
    include("${vcpkg_ROOT}/scripts/buildsystems/vcpkg.cmake")
endif()
