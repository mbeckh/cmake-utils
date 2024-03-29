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
# Common build settings for Visual Studio 2019 used in regular builds but not vcpkg.
#
include_guard(GLOBAL)

message(STATUS "Applying common settings: ${CMAKE_CURRENT_LIST_DIR}")
include("${CMAKE_CURRENT_LIST_DIR}/_shared.cmake")

# Remaining settings are MSVC only (i.e. not relevant for analysis with clang-tidy)
if(NOT MSVC)
    return()
endif()

#
# set_compile_pdb(<target>)
#
# Required because the following does not work:
# set(CMAKE_COMPILE_PDB_OUTPUT_DIRECTORY "$<TARGET_FILE_DIR:$<TARGET_PROPERTY:NAME>>")
#
function(z_cmake_utils_set_compile_pdb target)
    get_target_property(imported "${target}" IMPORTED)
    get_target_property(aliased "${target}" ALIASED_TARGET)
    get_target_property(type "${target}" TYPE)
    if(imported OR aliased OR type STREQUAL "INTERFACE_LIBRARY")
        return()
    endif()
    set_target_properties("${target}" PROPERTIES
        COMPILE_PDB_NAME "" # use default
        COMPILE_PDB_OUTPUT_DIRECTORY "$<TARGET_FILE_DIR:${target}>")
endfunction()

block()
    # Generator expression list for detecting dependency to Google Test
    set(gtest_targets "")
    foreach(target GTest::gtest GTest::gmock detours::gmock)
        list(APPEND gtest_targets "$<IN_LIST:${target},$<TARGET_PROPERTY:LINK_LIBRARIES>>")
    endforeach()
    list(JOIN gtest_targets "," gtest_targets)

    set(debug "$<OR:$<AND:$<CONFIG:Debug>,$<NOT:$<BOOL:${CMU_DISABLE_DEBUG_INFORMATION_DEBUG}>>>,$<AND:$<CONFIG:RelWithDebInfo>,$<NOT:$<BOOL:${CMU_DISABLE_DEBUG_INFORMATION_RELWITHDEBINFO}>>>>")

    #
    # Compiler options
    #

    # Treat all non-local packages (e.g. in vcpkg) as third party code
    #if((config MATCHES "DE?BU?G" OR CMAKE_BUILD_TYPE MATCHES "WITHDEBINFO") AND NOT CMU_DISABLE_DEBUG_INFORMATION AND NOT CMU_DISABLE_DEBUG_INFORMATION_${config})
        # Configurations matching Debug, Dbg, Debg, Dbug and WithDebInfo (case insensitive) are treated as debug
    #    set(CMAKE_VS_JUST_MY_CODE_DEBUGGING ON CACHE BOOL "")
    #endif()
    if(NOT CMU_DISABLE_DEBUG_INFORMATION)
        set(CMAKE_VS_JUST_MY_CODE_DEBUGGING "$<IF:${debug},ON,OFF>" CACHE BOOL "")
    endif()

    # Includes
    if(NOT CMU_DISABLE_DEBUG_INFORMATION)
        # Debug information
        set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT "$<${debug}:$<IF:$<CONFIG:Debug>,EditAndContinue,Embedded>>" CACHE STRING "")
        cmake_policy(GET CMP0141 msvc_debug_information_format)
        if(msvc_debug_information_format STREQUAL NEW)
            add_compile_options("$<$<AND:${debug},$<COMPILE_LANGUAGE:C,CXX>>:/FS>")
        else()
            add_compile_options("$<$<AND:${debug},$<COMPILE_LANGUAGE:C,CXX>>:$<IF:$<CONFIG:Debug>,/ZI,/Z7>;/FS>")
        endif()

        # Google Test Adapter requires full paths (which prohibits the use of /d1trimfile)
        # OpenCppCoverage requires untrimmed paths to apply filtering
        add_compile_options("$<$<AND:${debug},$<COMPILE_LANGUAGE:C,CXX>,$<OR:${gtest_targets}>>:/FC>"
                            # cannot combine into one argument because CMake gets trailing backslash wrong
                            "$<$<AND:${debug},$<COMPILE_LANGUAGE:C,CXX>,$<NOT:$<OR:$<CONFIG:Debug>,${gtest_targets}>>>:/d1trimfile:$<SHELL_PATH:$<TARGET_PROPERTY:SOURCE_DIR>/>>"
                            "$<$<AND:${debug},$<COMPILE_LANGUAGE:C,CXX>,$<NOT:$<OR:$<CONFIG:Debug>,${gtest_targets}>>>:/d1trimfile:$<SHELL_PATH:$<TARGET_PROPERTY:BINARY_DIR>/>>")

        # Place program database in output folder using the default name, else single file compilation is broken in Visual Studio
        # cf. https://developercommunity.visualstudio.com/t/CMake-single-file-compilation-broken-whe/1394819
        # Not used in vcpkg which uses /Z7. Also do not interfere with PDB handling in port.
        # Currently disabled because /Zi gives linker warnings because of parallel access to pdb in root directory
        # cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}" CALL cmake_utils_for_each_target z_cmake_utils_set_compile_pdb)
    endif()

    #
    # Linker options
    #

    # Debug information
    # Google Test Adapter requires /DEBUG:FULL
    if(CMU_DISABLE_DEBUG_INFORMATION)
        add_link_options("/DEBUG:NONE")
    else()
        #add_link_options("/DEBUG:$<IF:$<OR:$<NOT:$<CONFIG:Debug>>,${gtest_targets}>,FULL,FASTLINK>")
        # Fix for https://developercommunity.visualstudio.com/t/VS2022-linkexe-access-violation-when-us/10094721
        # Also see https://devblogs.microsoft.com/cppblog/playground-games-and-turn-10-studios-see-18-2x-and-4-95x-link-time-improvements-respectively-on-visual-studio-2019/#comments for reasons for not using /DEBUG:FASTLINK
        add_link_options("/DEBUG:$<IF:${debug},FULL,NONE>")
    endif()
endblock()
