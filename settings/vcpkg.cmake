#
# Common tool chain for Visual Studio 2019 with vcpkg.
#
# MIT License, Copyright (c) 2021 Michael Beckh, see LICENSE
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
