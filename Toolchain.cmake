#
# Tool chain for use by project and vcpkg.
#
# MIT License, Copyright (c) 2021 Michael Beckh, see LICENSE
#

#
# Function to keep namespaces cleaner.
#
function(z_cmake_utils_toolchain)
    get_property(try_compile GLOBAL PROPERTY IN_TRY_COMPILE)
    if(try_compile)
        return()
    endif()

    if(VCPKG_CHAINLOAD_TOOLCHAIN_FILE)
        set(file "settings/vcpkg")
    else()
        set(file "cmake-utils")
    endif()

    if(CMAKE_PROJECT_INCLUDE)
        if(NOT CMAKE_PROJECT_INCLUDE STREQUAL "${CMAKE_CURRENT_LIST_DIR}/modules/${file}.cmake")
            message(FATAL_ERROR "Using cmake-utils together with CMAKE_PROJECT_INCLUDE is not yet supported")
        endif()
    else()
        # Inject common build settings
        set(CMAKE_PROJECT_INCLUDE "${CMAKE_CURRENT_LIST_DIR}/modules/${file}.cmake" CACHE FILEPATH "")
    endif()
endfunction()

z_cmake_utils_toolchain()
