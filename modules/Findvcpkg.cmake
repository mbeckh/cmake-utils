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
set(vcpkg_INSTALL_REVISION "70033dbb31527fb3e69654731f540f59c87787f9" CACHE STRING "Revision of vcpkg if not using system binaries")

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

function(z_vcpkg_check_build_root_absolute)
    cmake_path(IS_ABSOLUTE BUILD_ROOT absolute)
    if(NOT absolute)
        message(FATAL_ERROR "BUILD_ROOT must be an absolute path: ${BUILD_ROOT}")
    endif()
endfunction()
z_vcpkg_check_build_root_absolute()

set(BUILD_ROOT "${BUILD_ROOT}" CACHE PATH "Root output directory for all projects")

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

function(z_vcpkg_add_tests)
    if(PROJECT_IS_TOP_LEVEL AND BUILD_TESTING)
        file(READ "${CMAKE_SOURCE_DIR}/vcpkg.json" content)
        set(result "${VCPKG_MANIFEST_FEATURES}")
        foreach(feature "test" "tests" "testing")
            string(JSON tests_feature ERROR_VARIABLE error GET "${content}" "features" "${feature}")
            if(tests_feature)
                list(APPEND result "${feature}")
            endif()
        endforeach()
        set(VCPKG_MANIFEST_FEATURES "${result}" PARENT_SCOPE)
    endif()
endfunction()
z_vcpkg_add_tests()

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
    set_target_properties("${target}" PROPERTIES vcpkg_LOCAL YES)
endfunction()

function(z_vcpkg_fix_local_includes_for_target main_target target)
    if(NOT target)
        set(target "${main_target}")
    endif()
    get_target_property(imported "${target}" IMPORTED)
    if(NOT imported)
        get_target_property(source "${target}" SOURCE_DIR)
        get_target_property(libs "${target}" LINK_LIBRARIES)
        foreach(lib IN LISTS libs)
            if(TARGET "${lib}")
                get_target_property(is_local "${lib}" vcpkg_LOCAL)
                if(is_local)
                    get_target_property(lib_source "${lib}" SOURCE_DIR)
                    if(NOT source STREQUAL lib_source)
                        message("${main_target}: Fixing include for ${lib}")
                        get_target_property(includes "${lib}" INTERFACE_SYSTEM_INCLUDE_DIRECTORIES)
                        target_include_directories("${main_target}" SYSTEM PRIVATE ${includes})
                        z_vcpkg_fix_local_includes_for_target("${main_target}" "${lib}")
                    endif()
                endif()
            endif()
        endforeach()
    endif()
endfunction()

function(z_vcpkg_fix_local_includes target)
    z_vcpkg_fix_local_includes_for_target("${target}" "${target}")
endfunction()

function(z_vcpkg_add_path name list suffix)
    set(vcpkg_paths
        "${VCPKG_INSTALLED_DIR}/_local-${name}/${VCPKG_TARGET_TRIPLET}${suffix}"
        "${VCPKG_INSTALLED_DIR}/_local-${name}/${VCPKG_TARGET_TRIPLET}/debug${suffix}"
    )
    if(NOT DEFINED CMAKE_BUILD_TYPE OR CMAKE_BUILD_TYPE MATCHES "^[Dd][Ee][Bb][Uu][Gg]$")
        list(REVERSE vcpkg_paths) # Debug build: Put Debug paths before Release paths.
    endif()
    if(VCPKG_PREFER_SYSTEM_LIBS)
        list(APPEND "${list}" "${vcpkg_paths}")
    else()
        list(PREPEND "${list}" "${vcpkg_paths}")
    endif()
    set("${list}" "${${list}}" PARENT_SCOPE)
endfunction()

function(z_vcpkg_run name source_dir)
    if(NOT EXISTS "${source_dir}/vcpkg.json")
        return()
    endif()

    message(STATUS "${name}: Running vcpkg install")

    unset(args)

    if(DEFINED VCPKG_HOST_TRIPLET AND VCPKG_HOST_TRIPLET STREQUAL "")
        list(APPEND args "--host-triplet=${VCPKG_HOST_TRIPLET}")
    endif()

    if(VCPKG_OVERLAY_PORTS)
        foreach(port IN LISTS VCPKG_OVERLAY_PORTS)
            list(APPEND args "--overlay-ports=${port}")
        endforeach()
    endif()

    if(VCPKG_OVERLAY_TRIPLETS)
        foreach(triplet IN LISTS VCPKG_OVERLAY_TRIPLETS)
            list(APPEND args "--overlay-triplets=${triplet}")
        endforeach()
    endif()

    if(DEFINED VCPKG_FEATURE_FLAGS OR DEFINED CACHE{VCPKG_FEATURE_FLAGS})
        list(JOIN VCPKG_FEATURE_FLAGS "," feature_flags)
        set(feature_flags "--feature-flags=${feature_flags}")
    endif()

    foreach(feature IN LISTS VCPKG_MANIFEST_FEATURES)
        # list(APPEND args "--x-feature=${feature}")
    endforeach()

    if(VCPKG_MANIFEST_NO_DEFAULT_FEATURES)
        list(APPEND args "--x-no-default-features")
    endif()

    if(NOT vcpkg_EXE)
        find_program(vcpkg_EXE vcpkg PATHS "${vcpkg_ROOT}" NO_DEFAULT_PATH)
    endif()
    execute_process(
        COMMAND "${vcpkg_EXE}" install
                "--triplet=${VCPKG_TARGET_TRIPLET}"
                "--vcpkg-root=${vcpkg_ROOT}"
                "--x-wait-for-lock"
                "--x-manifest-root=${source_dir}"
                "--x-install-root=${VCPKG_INSTALLED_DIR}/_local-${name}"
                "${feature_flags}"
                ${args}
                ${VCPKG_INSTALL_OPTIONS}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE output
        ECHO_OUTPUT_VARIABLE
        ECHO_ERROR_VARIABLE)

    file(TO_NATIVE_PATH "${CMAKE_BINARY_DIR}/vcpkg-manifest-install-${name}.log" log_file)
    file(WRITE "${log_file}" "${output}")

    if(result EQUAL 0)
        message(STATUS "${name}: Running vcpkg install - done")

        file(TOUCH "${VCPKG_INSTALLED_DIR}/_local-${name}/.cmakestamp")
        set_property(DIRECTORY "${CMAKE_SOURCE_DIR}" APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${source_dir}/vcpkg.json" "${VCPKG_INSTALLED_DIR}/_local-${name}/.cmakestamp")
        if(EXISTS "${source_dir}/vcpkg-configuration.json")
            set_property(DIRECTORY "${CMAKE_SOURCE_DIR}" APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${source_dir}/vcpkg-configuration.json")
        endif()
    else()
        message(STATUS "${name}: Running vcpkg install - failed")
        message(FATAL_ERROR "${name}: vcpkg install failed. See logs for more information: ${log_file}")
    endif()

    z_vcpkg_add_path("${name}" CMAKE_PREFIX_PATH "")
    z_vcpkg_add_path("${name}" CMAKE_LIBRARY_PATH "/lib/manual-link")
    z_vcpkg_add_path("${name}" CMAKE_FIND_ROOT_PATH "")
	
	set(CMAKE_PREFIX_PATH "${CMAKE_PREFIX_PATH}" PARENT_SCOPE)
	set(CMAKE_LIBRARY_PATH "${CMAKE_LIBRARY_PATH}" PARENT_SCOPE)
	set(CMAKE_FIND_ROOT_PATH "${CMAKE_FIND_ROOT_PATH}" PARENT_SCOPE)
endfunction()

function(z_vcpkg_configure_local_package name)
    get_property(local GLOBAL PROPERTY vcpkg_LOCAL_DEPENDENCY_NAMES)
    if(NOT name IN_LIST local)
        set_property(GLOBAL APPEND PROPERTY vcpkg_LOCAL_DEPENDENCY_NAMES "${name}")
        z_vcpkg_run("${name}" "${LOCAL_${name}_ROOT}")
        add_subdirectory("${LOCAL_${name}_ROOT}" "${CMAKE_BINARY_DIR}/_local/${name}" EXCLUDE_FROM_ALL)
        cmake_utils_for_each_target(z_vcpkg_configure_local_target DIRECTORY "${LOCAL_${name}_ROOT}")
        
        get_property(hook GLOBAL PROPERTY vcpkg_LOCAL_DEPENDENCY_HOOK)
        if(NOT hook)
            cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}" CALL cmake_utils_for_each_target z_vcpkg_fix_local_includes)
            set_property(GLOBAL PROPERTY vcpkg_LOCAL_DEPENDENCY_HOOK YES)
        endif()
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
