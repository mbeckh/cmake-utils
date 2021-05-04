#
# Common build settings for Visual Studio 2019 used in regular builds but not vcpkg.
#
# MIT License, Copyright (c) 2021 Michael Beckh, see LICENSE
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

#
# Function to keep global scope cleaner.
#
function(z_cmake_utils_settings_common)
    # Generator expression list for detecting dependency to Google Test
    set(gtest_targets "")
    foreach(target GTest::gtest GTest::gmock detours::gmock)
        list(APPEND gtest_targets "$<IN_LIST:${target},$<TARGET_PROPERTY:LINK_LIBRARIES>>")
    endforeach()
    list(JOIN gtest_targets "," gtest_targets)

    #
    # Compiler options
    #

    # Treat all non-local packages (e.g. in vcpkg) as third party code
    set(CMAKE_VS_JUST_MY_CODE_DEBUGGING ON CACHE BOOL "")

    # Includes
    add_compile_options("$<$<COMPILE_LANGUAGE:C,CXX>:/experimental:external;/external:W0>")
    set(CMAKE_INCLUDE_SYSTEM_FLAG_CXX "/external:I " CACHE STRING "" FORCE)

    # Debug information
    add_compile_options("$<$<COMPILE_LANGUAGE:C,CXX>:$<IF:$<CONFIG:Debug>,/ZI,/Zi>;/FS>")

    # Google Test Adapter requires full paths (which prohibits the use of /d1trimfile)
    add_compile_options("$<$<AND:$<COMPILE_LANGUAGE:C,CXX>,$<OR:${gtest_targets}>>:/FC>"
                        # cannot combine into one argument because CMake gets trailing backslash wrong
                        "$<$<AND:$<COMPILE_LANGUAGE:C,CXX>,$<NOT:$<OR:${gtest_targets}>>>:/d1trimfile:$<SHELL_PATH:$<TARGET_PROPERTY:SOURCE_DIR>/>>"
                        "$<$<AND:$<COMPILE_LANGUAGE:C,CXX>,$<NOT:$<OR:${gtest_targets}>>>:/d1trimfile:$<SHELL_PATH:$<TARGET_PROPERTY:BINARY_DIR>/>>")

    # Place program database in output folder using the default name, else single file compilation is broken in Visual Studio
    # cf. https://developercommunity.visualstudio.com/t/CMake-single-file-compilation-broken-whe/1394819
    # Not used in vcpkg which uses /Z7. Also do not interfere with PDB handling in port.
    cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}" CALL cmake_utils_for_each_target z_cmake_utils_set_compile_pdb)

    #
    # Linker options
    #

    # Debug information
    # Google Test Adapter requires /DEBUG:FULL
    add_link_options("/DEBUG:$<IF:$<OR:$<NOT:$<CONFIG:Debug>>,${gtest_targets}>,FULL,FASTLINK>")
endfunction()

z_cmake_utils_settings_common()
