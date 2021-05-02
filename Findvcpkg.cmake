#
# Load and configure vcpkg.
#
# MIT License, Copyright (c) 2021 Michael Beckh, see LICENSE
#
if(vcpkg_FOUND)
    return()
endif()

# vcpkg revision
set(VCPKG_REVISION "395cb682bd8f9cc65228f48e40390f5241373659" CACHE STRING "Revision of vcpkg")

#
# Check and configure required settings
#
if(NOT BUILD_ROOT)
    if(DEFINED ENV{BUILD_ROOT})
        # allow unified access to value for cache and environment variable
        set(BUILD_ROOT "$ENV{BUILD_ROOT}" CACHE PATH "Root output directory for all projects")
    else()
        message(FATAL_ERROR "Build requires setting BUILD_ROOT to a valid output directory")
	endif()
endif()

if(NOT DEFINED VCPKG_ROOT)
    set(VCPKG_ROOT "${BUILD_ROOT}/vcpkg" CACHE PATH "Root directory for vcpkg program and packages")
endif()

#
# Load or update vcpkg
#
include(FindPackageHandleStandardArgs)

if(EXISTS "${VCPKG_ROOT}/.git/HEAD")
    file(READ "${VCPKG_ROOT}/.git/HEAD" vcpkg_current_revision)
    if(vcpkg_current_revision MATCHES "${VCPKG_REVISION}")
        find_package_handle_standard_args(vcpkg REQUIRED_VARS VCPKG_ROOT VERSION_VAR VCPKG_REVISION)
    else()
        find_package(Git REQUIRED)
        if (Git_FOUND)
            execute_process(COMMAND "${GIT_EXECUTABLE}" "fetch" WORKING_DIRECTORY "${VCPKG_ROOT}")
            execute_process(COMMAND "${GIT_EXECUTABLE}" "checkout" "${VCPKG_REVISION}" WORKING_DIRECTORY "${VCPKG_ROOT}")
        endif()
        find_package_handle_standard_args(vcpkg REQUIRED_VARS Git_FOUND VCPKG_ROOT VERSION_VAR VCPKG_REVISION)
    endif()
    unset(vcpkg_current_revision)
elseif(EXISTS "${VCPKG_ROOT}/.vcpkg-root")
    find_program(vcpkg_EXE PATHS "${VCPKG_ROOT}" NO_DEFAULT_PATH)
    if(vcpkg_EXE)
        execute_process(COMMAND "${vcpkg_EXE}" version OUTPUT_VARIABLE out)
        if(out MATCHES "Vcpkg package management program version [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-([0-9a-f]+)")
            set(VCPKG_REVISION "${CMAKE_MATCH_1}")
        else()
            unset(VCPKG_REVISION)
        endif()
    endif()
    find_package_handle_standard_args(vcpkg REQUIRED_VARS VCPKG_ROOT VERSION_VAR VCPKG_REVISION)
else()
    find_package(Git REQUIRED)
    if (Git_FOUND)
        execute_process(COMMAND "${GIT_EXECUTABLE}" "clone" "--no-checkout" "https://github.com/microsoft/vcpkg.git" "${VCPKG_ROOT}")
        execute_process(COMMAND "${GIT_EXECUTABLE}" "checkout" "--quiet" "${VCPKG_REVISION}" WORKING_DIRECTORY "${VCPKG_ROOT}")
    endif()
    find_package_handle_standard_args(vcpkg REQUIRED_VARS Git_FOUND VCPKG_ROOT VERSION_VAR VCPKG_REVISION)
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

set(project_root_path "${CMAKE_BINARY_DIR}")
# Two folders up
cmake_path(GET project_root_path PARENT_PATH project_root_path) # strip configuration name
cmake_path(GET project_root_path PARENT_PATH project_root_path) # strip "build"
set(VCPKG_INSTALL_OPTIONS "--x-buildtrees-root=${project_root_path}/vcpkg-buildtrees;--x-packages-root=${project_root_path}/vcpkg-packages" CACHE STRING "Additional options for vcpkg")
unset(folder_name)
# vcpkg does not yet allow setting the packages directory to a custom folder
set(ENV{LOCALAPPDATA} "${BUILD_ROOT}/vcpkg-local-app-data")

set(VCPKG_OVERRIDE_FIND_PACKAGE_NAME "vcpkg_find_package")

#
# configure_local_vcpkg_package(<target>)
#
# Change config settings for vcpkg packages included from a local path.
#
function(configure_local_vcpkg_package target)
    get_property(includes TARGET ${target} PROPERTY INTERFACE_INCLUDE_DIRECTORIES)
    set_property(TARGET ${target} APPEND PROPERTY INTERFACE_SYSTEM_INCLUDE_DIRECTORIES ${includes})
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
                get_property(local_vcpkg_dependency_names GLOBAL PROPERTY LOCAL_VCPKG_DEPENDENCY_NAMES)
                if(NOT "${name}" IN_LIST local_vcpkg_dependency_names)
                    set_property(GLOBAL APPEND PROPERTY LOCAL_VCPKG_DEPENDENCY_NAMES "${name}")
                    add_subdirectory("${LOCAL_${name}_ROOT}" "${CMAKE_BINARY_DIR}/_local/${name}" EXCLUDE_FROM_ALL)
                    cmake_utils_for_each_target(configure_local_vcpkg_package DIRECTORY "${LOCAL_${name}_ROOT}")
                endif()
                unset(local_vcpkg_dependency_names)
                unset(now)
            endif()
        elseif(COMMAND vcpkg_find_package)
            vcpkg_find_package(${ARGV})
        else()
            _find_package(${ARGV})
        endif()
    endmacro()
endif()

if(vcpkg_FOUND)
    include("${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")
endif()
